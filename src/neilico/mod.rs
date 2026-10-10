// SPDX-License-Identifier: AGPL-3.0-only
pub mod mesh;
pub mod remote_desktop;

use hbb_common::config::{self, Config};
use serde_json::{json, Value};
use std::{process::Child, thread, time::Duration};

pub const FEATURE_MESH: &str = "mesh";
pub const FEATURE_REMOTE_DESKTOP: &str = "remote_desktop";

#[derive(Clone, Copy)]
pub enum Feature {
    Mesh,
    RemoteDesktop,
}

impl Feature {
    fn parse(name: &str) -> Result<Self, String> {
        match name {
            FEATURE_MESH => Ok(Self::Mesh),
            FEATURE_REMOTE_DESKTOP => Ok(Self::RemoteDesktop),
            _ => Err(format!("unknown NEILICO feature: {name}")),
        }
    }

    fn option_key(self) -> &'static str {
        match self {
            Self::Mesh => base::config::keys::OPTION_NEILICO_MESH_ENABLED,
            Self::RemoteDesktop => base::config::keys::OPTION_NEILICO_REMOTE_DESKTOP_ENABLED,
        }
    }

    fn policy_key(self) -> &'static str {
        match self {
            Self::Mesh => "neilico-forbid-mesh",
            Self::RemoteDesktop => "neilico-forbid-remote-desktop",
        }
    }
}

pub fn enabled(feature: Feature) -> bool {
    Config::get_option(feature.option_key()) == "Y"
}

pub fn policy_forbidden(feature: Feature) -> bool {
    config::HARD_SETTINGS
        .read()
        .unwrap()
        .get(feature.policy_key())
        .map(|value| value == "Y")
        .unwrap_or(false)
}

pub fn set_enabled(feature_name: &str, enable: bool) -> Result<(), String> {
    let feature = Feature::parse(feature_name)?;
    if enable && policy_forbidden(feature) {
        return Err("由控制面策略强制禁止".to_owned());
    }
    let result = match feature {
        Feature::Mesh => mesh::set_enabled(enable),
        Feature::RemoteDesktop => remote_desktop::set_enabled(enable),
    };
    if !enable {
        Config::set_option(feature.option_key().to_owned(), "N".to_owned());
    }
    result?;
    if enable {
        Config::set_option(feature.option_key().to_owned(), "Y".to_owned());
    }
    Ok(())
}

pub fn status(feature_name: &str) -> Result<Value, String> {
    let feature = Feature::parse(feature_name)?;
    let running = match feature {
        Feature::Mesh => mesh::running(),
        Feature::RemoteDesktop => remote_desktop::running(),
    };
    let error = match feature {
        Feature::Mesh => mesh::last_error(),
        Feature::RemoteDesktop => remote_desktop::last_error(),
    };
    Ok(json!({
        "enabled": enabled(feature),
        "running": running,
        "policy_forbidden": policy_forbidden(feature),
        "error": error,
    }))
}

pub fn apply_control_policy(value: Value) -> Result<(), String> {
    let object = value
        .as_object()
        .ok_or_else(|| "control policy must be a JSON object".to_owned())?;
    for (feature_name, action) in object {
        let feature = Feature::parse(feature_name)?;
        let action = action
            .as_str()
            .ok_or_else(|| format!("policy action for {feature_name} must be a string"))?;
        match action {
            "deny" => {
                config::HARD_SETTINGS
                    .write()
                    .unwrap()
                    .insert(feature.policy_key().to_owned(), "Y".to_owned());
                set_enabled(feature_name, false)?;
            }
            "allow" => {
                config::HARD_SETTINGS
                    .write()
                    .unwrap()
                    .remove(feature.policy_key());
            }
            _ => {
                return Err(format!(
                    "unsupported policy action for {feature_name}: {action}"
                ))
            }
        }
    }
    Ok(())
}

fn finish_child(mut child: Child) -> Result<(), String> {
    let pid = child.id();
    #[cfg(unix)]
    {
        let status = std::process::Command::new("kill")
            .args(["-TERM", &pid.to_string()])
            .status()
            .map_err(|err| format!("failed to signal child process {pid}: {err}"))?;
        if !status.success() {
            if let Some(result) = child.try_wait().map_err(|err| err.to_string())? {
                if result.success() {
                    return Ok(());
                }
            }
            return Err(format!("failed to signal child process {pid}"));
        }
    }
    #[cfg(windows)]
    child
        .kill()
        .map_err(|err| format!("failed to stop child process {pid}: {err}"))?;

    for _ in 0..100 {
        if child.try_wait().map_err(|err| err.to_string())?.is_some() {
            return Ok(());
        }
        thread::sleep(Duration::from_millis(100));
    }

    child
        .kill()
        .map_err(|err| format!("failed to force-stop child process {pid}: {err}"))?;
    child.wait().map_err(|err| err.to_string())?;
    Ok(())
}

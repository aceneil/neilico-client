// SPDX-License-Identifier: AGPL-3.0-only
use base::config::keys;
use hbb_common::config::Config;
use std::{
    fs::{self, File},
    path::PathBuf,
    process::{Child, Command, Stdio},
    sync::Mutex,
};

static CHILD: Mutex<Option<Child>> = Mutex::new(None);
static LAST_ERROR: Mutex<String> = Mutex::new(String::new());

pub fn set_enabled(enable: bool) -> Result<(), String> {
    if !enable {
        return stop();
    }
    if running() {
        return Ok(());
    }
    if crate::neilico::policy_forbidden(crate::neilico::Feature::Mesh) {
        return Err("由控制面策略强制禁止".to_owned());
    }
    let state_dir = state_dir()?;
    fs::create_dir_all(&state_dir)
        .map_err(|err| format!("failed to create agent state directory: {err}"))?;
    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        fs::set_permissions(&state_dir, fs::Permissions::from_mode(0o700))
            .map_err(|err| format!("failed to secure agent state directory: {err}"))?;
    }

    let server = Config::get_option(keys::OPTION_NEILICO_MESH_SERVER);
    let token = Config::get_option(keys::OPTION_NEILICO_MESH_TOKEN);
    let connection = Config::get_option(keys::OPTION_NEILICO_MESH_CONNECTION_STRING);
    let state_file = state_dir.join("state.json");
    if !state_file.is_file() && connection.trim().is_empty() && token.trim().is_empty() {
        return Err("请填写接入令牌或连接串".to_owned());
    }

    let exe_dir = std::env::current_exe()
        .map_err(|err| err.to_string())?
        .parent()
        .ok_or_else(|| "cannot locate application directory".to_owned())?
        .to_path_buf();
    let agent_name = if cfg!(windows) {
        "neilico-agent.exe"
    } else {
        "neilico-agent"
    };
    let agent = exe_dir.join(agent_name);
    if !agent.is_file() {
        return Err(format!("找不到内嵌 Mesh agent: {}", agent.display()));
    }

    let log_path = state_dir.join("agent.log");
    let log =
        File::create(&log_path).map_err(|err| format!("failed to create agent log: {err}"))?;
    let mut command = Command::new(agent);
    command
        .arg("--state-dir")
        .arg(&state_dir)
        .env("NEILICO_AGENT_NODE_NAME", crate::whoami_hostname())
        .env("NEILICO_AGENT_METRICS_ENABLED", "false")
        .env("NEILICO_AGENT_MESH_CLEANUP_ON_EXIT", "true")
        .stdin(Stdio::null())
        .stdout(Stdio::from(log.try_clone().map_err(|err| err.to_string())?))
        .stderr(Stdio::from(log));
    if !server.trim().is_empty() {
        command.env("NEILICO_AGENT_SERVER", server.trim());
    }
    if !connection.trim().is_empty() {
        command.env("NEILICO_TOKEN", connection.trim());
    } else if !token.trim().is_empty() {
        command.env("NEILICO_TOKEN", token.trim());
    }

    let child = command
        .spawn()
        .map_err(|err| format!("failed to start Mesh agent: {err}"))?;
    CHILD.lock().unwrap().replace(child);
    set_error("");
    Ok(())
}

pub fn running() -> bool {
    let mut slot = CHILD.lock().unwrap();
    let Some(child) = slot.as_mut() else {
        return false;
    };
    match child.try_wait() {
        Ok(None) => true,
        Ok(Some(status)) => {
            set_error_locked(&format!("Mesh agent exited with {status}"));
            *slot = None;
            false
        }
        Err(err) => {
            set_error_locked(&format!("failed to query Mesh agent: {err}"));
            false
        }
    }
}

pub fn last_error() -> String {
    LAST_ERROR.lock().unwrap().clone()
}

fn stop() -> Result<(), String> {
    let child = CHILD.lock().unwrap().take();
    if let Some(child) = child {
        super::finish_child(child)?;
    }
    if interface_exists() {
        let error = "Mesh 已停止，但 wg0 仍存在".to_owned();
        set_error(&error);
        return Err(error);
    }
    set_error("");
    Ok(())
}

fn state_dir() -> Result<PathBuf, String> {
    let config = Config::file();
    let parent = config
        .parent()
        .ok_or_else(|| "cannot locate application configuration directory".to_owned())?;
    Ok(parent.join("neilico-agent"))
}

fn interface_exists() -> bool {
    #[cfg(any(target_os = "linux", target_os = "macos"))]
    {
        Command::new("ip")
            .args(["link", "show", "dev", "wg0"])
            .stdout(Stdio::null())
            .stderr(Stdio::null())
            .status()
            .map(|status| status.success())
            .unwrap_or(false)
    }
    #[cfg(windows)]
    {
        Command::new("netsh")
            .args(["interface", "show", "interface", "name=wg0"])
            .stdout(Stdio::null())
            .stderr(Stdio::null())
            .status()
            .map(|status| status.success())
            .unwrap_or(false)
    }
}

fn set_error(error: &str) {
    *LAST_ERROR.lock().unwrap() = error.to_owned();
}

fn set_error_locked(error: &str) {
    *LAST_ERROR.lock().unwrap() = error.to_owned();
}

// SPDX-License-Identifier: AGPL-3.0-only
use hbb_common::log;
use std::{
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
    if crate::neilico::policy_forbidden(crate::neilico::Feature::RemoteDesktop) {
        return Err("由控制面策略强制禁止".to_owned());
    }
    let exe = std::env::current_exe().map_err(|err| err.to_string())?;
    let child = Command::new(exe)
        .arg("--neilico-remote-desktop")
        .stdin(Stdio::null())
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .spawn()
        .map_err(|err| format!("failed to start remote desktop service: {err}"))?;
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
            set_error_locked(&format!("remote desktop service exited with {status}"));
            *slot = None;
            false
        }
        Err(err) => {
            set_error_locked(&format!("failed to query remote desktop service: {err}"));
            false
        }
    }
}

pub fn last_error() -> String {
    LAST_ERROR.lock().unwrap().clone()
}

pub fn run_server_or_exit() {
    if crate::neilico::policy_forbidden(crate::neilico::Feature::RemoteDesktop)
        || !crate::neilico::enabled(crate::neilico::Feature::RemoteDesktop)
    {
        return;
    }
    crate::start_server(true, false);
}

pub fn run_managed_server_or_exit() {
    if crate::neilico::policy_forbidden(crate::neilico::Feature::RemoteDesktop) {
        return;
    }
    crate::start_server(true, false);
}

pub fn start_if_enabled() {
    if crate::neilico::policy_forbidden(crate::neilico::Feature::RemoteDesktop)
        || !crate::neilico::enabled(crate::neilico::Feature::RemoteDesktop)
    {
        return;
    }
    if let Err(err) = set_enabled(true) {
        set_error(&err);
        log::error!("failed to start remote desktop service: {err}");
    }
}

fn stop() -> Result<(), String> {
    let child = CHILD.lock().unwrap().take();
    if let Some(child) = child {
        super::finish_child(child)?;
    }
    set_error("");
    Ok(())
}

fn set_error(error: &str) {
    *LAST_ERROR.lock().unwrap() = error.to_owned();
}

fn set_error_locked(error: &str) {
    *LAST_ERROR.lock().unwrap() = error.to_owned();
}

use std::{
    ffi::OsString,
    sync::mpsc,
    time::Duration,
    thread,
};
use windows_service::{
    define_windows_service,
    service::{
        ServiceControl, ServiceControlAccept, ServiceExitCode, ServiceState, ServiceStatus,
        ServiceType,
    },
    service_control_handler::{self, ServiceControlHandlerResult},
    service_dispatcher,
};
use log::{error, info};
use chrono::Local;
use anyhow::{Context, Result};

const SERVICE_NAME: &str = "Exp01WinService";
const SERVICE_TYPE: ServiceType = ServiceType::OWN_PROCESS;

pub fn main() -> Result<()> {
    // Initialize logging
    log4rs::init_file(r"C:\Projekte\rust-experiments\exp01_winsrv\log4rs.yaml", Default::default())?;

    if let Err(e) = service_dispatcher::start(SERVICE_NAME, ffi_service_main) {
        error!("Service dispatcher error: {}", e);
        return Err(e.into());
    }
    Ok(())
}

define_windows_service!(ffi_service_main, service_main);

fn service_main(arguments: Vec<OsString>) {
    info!("Service starting with {:?} arguments", arguments);
    if let Err(e) = run_service() {
        error!("Service error: {}", e);
    }
}

fn run_service() -> Result<()> {
    info!("Initializing service...");

    // Create a channel to communicate with the event handler
    let (shutdown_tx, shutdown_rx) = mpsc::channel();

    // Define the event handler
    let event_handler = move |control_event| -> ServiceControlHandlerResult {
        match control_event {
            ServiceControl::Stop => {
                info!("Service stop requested");
                match shutdown_tx.send(()) {
                    Ok(_) => info!("Stop request successfully relayed"),
                    Err(x) => error!("Stop request not successfully relayed {}", x),
                }
                ServiceControlHandlerResult::NoError
            }
            ServiceControl::Interrogate => ServiceControlHandlerResult::NoError,
            _ => ServiceControlHandlerResult::NotImplemented,
        }
    };

    // Register the event handler
    let status_handle = service_control_handler::register(SERVICE_NAME, event_handler)
        .context("Failed to register service control handler")?;

    // Tell the system that the service is running
    status_handle.set_service_status(ServiceStatus {
        service_type: SERVICE_TYPE,
        current_state: ServiceState::Running,
        controls_accepted: ServiceControlAccept::STOP,
        exit_code: ServiceExitCode::Win32(0),
        checkpoint: 0,
        wait_hint: Duration::default(),
        process_id: None,
    })?;

    // Main service loop
    info!("Service started successfully");
    loop {
        // Check if we received a shutdown signal
        if shutdown_rx.try_recv().is_ok() {
            info!("Stop Request recieved and being processed");
            break;
        }

        // Log that we're running
        info!("I am running at {}", Local::now().format("%Y-%m-%d %H:%M:%S"));

        // Sleep for 60 seconds
        thread::sleep(Duration::from_secs(5));
    }

    
    status_handle.set_service_status(ServiceStatus {
        service_type: SERVICE_TYPE,
        current_state: ServiceState::StopPending,
        controls_accepted: ServiceControlAccept::empty(),
        exit_code: ServiceExitCode::Win32(0),
        checkpoint: 0,
        wait_hint: Duration::default(),
        process_id: None,
    })?;

    // Service is stopping
    info!("Service is stopping");

    status_handle.set_service_status(ServiceStatus {
        service_type: SERVICE_TYPE,
        current_state: ServiceState::Stopped,
        controls_accepted: ServiceControlAccept::empty(),
        exit_code: ServiceExitCode::Win32(0),
        checkpoint: 0,
        wait_hint: Duration::default(),
        process_id: None,
    })?;

    Ok(())
}

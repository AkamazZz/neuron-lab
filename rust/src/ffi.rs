use crate::core::{SimulationConfig, ValidationError};
use crate::experiments::{
    ExperimentDefinition, ExperimentRunner, ExperimentState, PhaseProgress, ResetMode,
};
use crate::simulation::{BatchStepOptions, Network, SpikeEvent, StepFrame, StepInput};
use serde::Serialize;
use std::collections::HashMap;
use std::ffi::c_void;
use std::panic::{AssertUnwindSafe, catch_unwind};
use std::slice;
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::{LazyLock, Mutex};

pub const ABI_VERSION: u32 = 1;

static NEXT_HANDLE: AtomicU64 = AtomicU64::new(1);
static REGISTRY: LazyLock<Mutex<HashMap<u64, SimulationHost>>> =
    LazyLock::new(|| Mutex::new(HashMap::new()));

#[repr(C)]
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct CcnSimulationHandle {
    pub id: u64,
}

#[repr(C)]
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct CcnStatus {
    pub code: u32,
    pub error_kind: u32,
    pub message: CcnBuffer,
}

#[repr(C)]
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct CcnBuffer {
    pub ptr: *mut u8,
    pub len: usize,
    pub cap: usize,
}

#[repr(C)]
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct CcnSpikeEvent {
    pub step_offset: u32,
    pub absolute_step: u64,
    pub neuron_id: u32,
    pub membrane: f32,
}

#[repr(C)]
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct CcnStepFrame {
    pub start_step: u64,
    pub steps: u32,
    pub event_count: usize,
    pub events: *mut CcnSpikeEvent,
}

#[repr(C)]
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct CcnPhaseProgress {
    pub phase_index: u32,
    pub phase_step: u32,
    pub phase_duration: u32,
    pub total_step: u32,
    pub total_duration: u32,
    pub progress: f32,
}

struct SimulationHost {
    network: Network,
    runner: ExperimentRunner,
}

impl CcnBuffer {
    pub fn empty() -> Self {
        Self {
            ptr: std::ptr::null_mut(),
            len: 0,
            cap: 0,
        }
    }
}

impl CcnStatus {
    fn ok() -> Self {
        Self {
            code: 0,
            error_kind: 0,
            message: CcnBuffer::empty(),
        }
    }

    fn error(kind: ErrorKind, message: impl Into<String>) -> Self {
        Self {
            code: 1,
            error_kind: kind as u32,
            message: buffer_from_bytes(message.into().into_bytes()),
        }
    }

    pub fn is_ok(&self) -> bool {
        self.code == 0
    }
}

#[repr(u32)]
#[derive(Clone, Copy, Debug)]
enum ErrorKind {
    InvalidHandle = 1,
    ValidationFailed = 2,
    InvalidArgument = 3,
    InternalError = 4,
}

#[unsafe(no_mangle)]
pub extern "C" fn ccn_abi_version() -> u32 {
    ABI_VERSION
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn ccn_validate_config(
    json_ptr: *const u8,
    json_len: usize,
    out_report: *mut CcnBuffer,
) -> CcnStatus {
    catch_status(|| {
        let config: SimulationConfig = unsafe { parse_json(json_ptr, json_len)? };
        match config.validate() {
            Ok(()) => {
                write_out(out_report, buffer_json(&ValidationReport::ok())?)?;
                Ok(())
            }
            Err(error) => {
                write_out(
                    out_report,
                    buffer_json(&ValidationReport::error(error.to_string()))?,
                )?;
                Err(StatusError::validation(error.to_string()))
            }
        }
    })
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn ccn_create_simulation(
    json_ptr: *const u8,
    json_len: usize,
    out_handle: *mut CcnSimulationHandle,
) -> CcnStatus {
    catch_status(|| {
        let config: SimulationConfig = unsafe { parse_json(json_ptr, json_len)? };
        let network = Network::new(config)?;
        let id = NEXT_HANDLE.fetch_add(1, Ordering::Relaxed);
        REGISTRY.lock().expect("registry lock").insert(
            id,
            SimulationHost {
                network,
                runner: ExperimentRunner::default(),
            },
        );
        write_out(out_handle, CcnSimulationHandle { id })?;
        Ok(())
    })
}

#[unsafe(no_mangle)]
pub extern "C" fn ccn_free_simulation(handle: CcnSimulationHandle) -> CcnStatus {
    catch_status(|| {
        let removed = REGISTRY.lock().expect("registry lock").remove(&handle.id);
        if removed.is_some() {
            Ok(())
        } else {
            Err(StatusError::invalid_handle())
        }
    })
}

#[unsafe(no_mangle)]
pub extern "C" fn ccn_raw_reset(handle: CcnSimulationHandle, mode: u32) -> CcnStatus {
    catch_status(|| {
        with_host(handle, |host| {
            match mode {
                2 => {
                    host.network = host
                        .network
                        .recreate_from_seed()
                        .map_err(StatusError::validation)?
                }
                _ => host.network.reset_state(),
            }
            Ok(())
        })
    })
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn ccn_raw_step(
    handle: CcnSimulationHandle,
    input_json_ptr: *const u8,
    input_json_len: usize,
    steps: u32,
    learning_enabled: bool,
    out_frame: *mut CcnStepFrame,
) -> CcnStatus {
    catch_status(|| {
        let input = if input_json_len == 0 {
            Vec::new()
        } else {
            unsafe { parse_json::<Vec<StepInput>>(input_json_ptr, input_json_len)? }
        };
        with_host(handle, |host| {
            let frame = host.network.step_batch(BatchStepOptions {
                steps,
                learning_enabled,
                input,
            });
            write_out(out_frame, frame_to_abi(frame))?;
            Ok(())
        })
    })
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn ccn_validate_experiment(
    json_ptr: *const u8,
    json_len: usize,
    out_report: *mut CcnBuffer,
) -> CcnStatus {
    catch_status(|| {
        let definition: ExperimentDefinition = unsafe { parse_json(json_ptr, json_len)? };
        match definition.validate() {
            Ok(()) => {
                write_out(out_report, buffer_json(&ValidationReport::ok())?)?;
                Ok(())
            }
            Err(error) => {
                write_out(
                    out_report,
                    buffer_json(&ValidationReport::error(error.to_string()))?,
                )?;
                Err(StatusError::validation(error.to_string()))
            }
        }
    })
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn ccn_load_experiment(
    handle: CcnSimulationHandle,
    json_ptr: *const u8,
    json_len: usize,
) -> CcnStatus {
    catch_status(|| {
        let definition: ExperimentDefinition = unsafe { parse_json(json_ptr, json_len)? };
        with_host(handle, |host| {
            host.runner
                .load(definition)
                .map_err(StatusError::validation)
        })
    })
}

#[unsafe(no_mangle)]
pub extern "C" fn ccn_clear_experiment(handle: CcnSimulationHandle) -> CcnStatus {
    catch_status(|| {
        with_host(handle, |host| {
            host.runner.clear();
            Ok(())
        })
    })
}

#[unsafe(no_mangle)]
pub extern "C" fn ccn_step_experiment(
    handle: CcnSimulationHandle,
    max_steps: u32,
    out_frame: *mut CcnStepFrame,
) -> CcnStatus {
    catch_status(|| {
        with_host(handle, |host| {
            let frame = host
                .runner
                .step(max_steps)
                .map_err(StatusError::validation)?;
            write_out(out_frame, frame_to_abi(frame))?;
            Ok(())
        })
    })
}

#[unsafe(no_mangle)]
pub extern "C" fn ccn_experiment_state(
    handle: CcnSimulationHandle,
    out_state: *mut u32,
) -> CcnStatus {
    catch_status(|| {
        with_host(handle, |host| {
            write_out(out_state, host.runner.state as u32)?;
            Ok(())
        })
    })
}

#[unsafe(no_mangle)]
pub extern "C" fn ccn_phase_progress(
    handle: CcnSimulationHandle,
    out_progress: *mut CcnPhaseProgress,
) -> CcnStatus {
    catch_status(|| {
        with_host(handle, |host| {
            write_out(out_progress, progress_to_abi(host.runner.progress()))?;
            Ok(())
        })
    })
}

#[unsafe(no_mangle)]
pub extern "C" fn ccn_experiment_result(
    handle: CcnSimulationHandle,
    out_buffer: *mut CcnBuffer,
) -> CcnStatus {
    catch_status(|| {
        with_host(handle, |host| {
            let result = host.runner.result().map_err(StatusError::validation)?;
            write_out(out_buffer, buffer_json(&result)?)?;
            Ok(())
        })
    })
}

#[unsafe(no_mangle)]
pub extern "C" fn ccn_activity_snapshot(
    handle: CcnSimulationHandle,
    out_buffer: *mut CcnBuffer,
) -> CcnStatus {
    catch_status(|| {
        with_host(handle, |host| {
            write_out(out_buffer, buffer_json(&host.network.activity_snapshot())?)?;
            Ok(())
        })
    })
}

#[unsafe(no_mangle)]
pub extern "C" fn ccn_weight_snapshot(
    handle: CcnSimulationHandle,
    out_buffer: *mut CcnBuffer,
) -> CcnStatus {
    catch_status(|| {
        with_host(handle, |host| {
            write_out(out_buffer, buffer_json(&host.network.weight_snapshot())?)?;
            Ok(())
        })
    })
}

#[unsafe(no_mangle)]
pub extern "C" fn ccn_free_step_frame(frame: CcnStepFrame) {
    if !frame.events.is_null() && frame.event_count > 0 {
        unsafe {
            drop(Vec::from_raw_parts(
                frame.events,
                frame.event_count,
                frame.event_count,
            ));
        }
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn ccn_free_buffer(buffer: CcnBuffer) {
    if !buffer.ptr.is_null() && buffer.cap > 0 {
        unsafe {
            drop(Vec::from_raw_parts(buffer.ptr, buffer.len, buffer.cap));
        }
    }
}

fn with_host<T>(
    handle: CcnSimulationHandle,
    f: impl FnOnce(&mut SimulationHost) -> Result<T, StatusError>,
) -> Result<T, StatusError> {
    let mut registry = REGISTRY.lock().expect("registry lock");
    let host = registry
        .get_mut(&handle.id)
        .ok_or_else(StatusError::invalid_handle)?;
    f(host)
}

fn catch_status(f: impl FnOnce() -> Result<(), StatusError>) -> CcnStatus {
    match catch_unwind(AssertUnwindSafe(f)) {
        Ok(Ok(())) => CcnStatus::ok(),
        Ok(Err(error)) => error.into_status(),
        Err(_) => CcnStatus::error(
            ErrorKind::InternalError,
            "panic caught at native ABI boundary",
        ),
    }
}

#[derive(Debug)]
struct StatusError {
    kind: ErrorKind,
    message: String,
}

impl StatusError {
    fn invalid_handle() -> Self {
        Self {
            kind: ErrorKind::InvalidHandle,
            message: "invalid simulation handle".to_string(),
        }
    }

    fn validation(error: impl ToString) -> Self {
        Self {
            kind: ErrorKind::ValidationFailed,
            message: error.to_string(),
        }
    }

    fn invalid_argument(message: impl Into<String>) -> Self {
        Self {
            kind: ErrorKind::InvalidArgument,
            message: message.into(),
        }
    }

    fn into_status(self) -> CcnStatus {
        CcnStatus::error(self.kind, self.message)
    }
}

impl From<serde_json::Error> for StatusError {
    fn from(value: serde_json::Error) -> Self {
        Self::invalid_argument(value.to_string())
    }
}

impl From<ValidationError> for StatusError {
    fn from(value: ValidationError) -> Self {
        Self::validation(value)
    }
}

unsafe fn parse_json<T: serde::de::DeserializeOwned>(
    ptr: *const u8,
    len: usize,
) -> Result<T, StatusError> {
    if ptr.is_null() && len > 0 {
        return Err(StatusError::invalid_argument("json pointer is null"));
    }
    let bytes = if len == 0 {
        &[][..]
    } else {
        unsafe { slice::from_raw_parts(ptr, len) }
    };
    Ok(serde_json::from_slice(bytes)?)
}

fn write_out<T>(out: *mut T, value: T) -> Result<(), StatusError> {
    if out.is_null() {
        return Err(StatusError::invalid_argument("output pointer is null"));
    }
    unsafe {
        out.write(value);
    }
    Ok(())
}

fn buffer_json<T: Serialize>(value: &T) -> Result<CcnBuffer, StatusError> {
    Ok(buffer_from_bytes(serde_json::to_vec(value)?))
}

fn buffer_from_bytes(mut bytes: Vec<u8>) -> CcnBuffer {
    let buffer = CcnBuffer {
        ptr: bytes.as_mut_ptr(),
        len: bytes.len(),
        cap: bytes.capacity(),
    };
    std::mem::forget(bytes);
    buffer
}

fn frame_to_abi(frame: StepFrame) -> CcnStepFrame {
    let mut events = frame
        .spikes
        .into_iter()
        .map(|event| CcnSpikeEvent {
            step_offset: event.step_offset,
            absolute_step: event.absolute_step,
            neuron_id: event.neuron_id,
            membrane: event.membrane,
        })
        .collect::<Vec<_>>();
    let event_count = events.len();
    let events_ptr = if events.is_empty() {
        std::ptr::null_mut()
    } else {
        events.as_mut_ptr()
    };
    std::mem::forget(events);
    CcnStepFrame {
        start_step: frame.start_step,
        steps: frame.steps,
        event_count,
        events: events_ptr,
    }
}

fn progress_to_abi(progress: PhaseProgress) -> CcnPhaseProgress {
    CcnPhaseProgress {
        phase_index: progress.phase_index,
        phase_step: progress.phase_step,
        phase_duration: progress.phase_duration,
        total_step: progress.total_step,
        total_duration: progress.total_duration,
        progress: progress.progress,
    }
}

#[derive(Serialize)]
struct ValidationReport {
    valid: bool,
    errors: Vec<String>,
}

impl ValidationReport {
    fn ok() -> Self {
        Self {
            valid: true,
            errors: Vec::new(),
        }
    }

    fn error(error: String) -> Self {
        Self {
            valid: false,
            errors: vec![error],
        }
    }
}

#[allow(dead_code)]
fn _assert_ffi_types_are_plain() {
    let _ = std::mem::size_of::<*mut c_void>();
    let _ = ExperimentState::Idle as u32;
    let _ = ResetMode::FullRecreateFromSeed as u32;
    let _ = SpikeEvent {
        step_offset: 0,
        absolute_step: 0,
        neuron_id: 0,
        membrane: 0.0,
    };
}

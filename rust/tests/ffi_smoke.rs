use ccn_simulation_core::core::SimulationConfig;
use ccn_simulation_core::experiments::{
    ExperimentDefinition, PatternSchedule, Phase, PhaseType, ResultConfig, ResultKind,
    pattern_recognition_preset,
};
use ccn_simulation_core::ffi::*;
use ccn_simulation_core::metrics::MetricWindow;
use ccn_simulation_core::patterns::Pattern;
use serde_json::Value;
use std::slice;

#[test]
fn abi_version_is_queryable() {
    assert_eq!(ccn_abi_version(), ABI_VERSION);
}

#[test]
fn handle_lifecycle_invalid_handle_and_double_free_statuses() {
    let config = serde_json::to_vec(&SimulationConfig::default()).unwrap();
    let mut handle = CcnSimulationHandle { id: 0 };
    let status = unsafe { ccn_create_simulation(config.as_ptr(), config.len(), &mut handle) };
    assert!(status.is_ok());
    assert_ne!(handle.id, 0);

    let status = ccn_free_simulation(handle);
    assert!(status.is_ok());

    let status = ccn_free_simulation(handle);
    assert_eq!(status.error_kind, 1);
    ccn_free_buffer(status.message);
}

#[test]
fn validation_error_returns_report_buffer() {
    let config = serde_json::json!({
        "schema_version": 99,
        "seed": null,
        "neuron_count": 1
    })
    .to_string();
    let mut report = CcnBuffer::empty();
    let status = unsafe { ccn_validate_config(config.as_ptr(), config.len(), &mut report) };

    assert!(!status.is_ok());
    assert_eq!(status.error_kind, 2);
    let text = buffer_to_string(report);
    assert!(text.contains("unsupported"));
    ccn_free_buffer(report);
    ccn_free_buffer(status.message);
}

#[test]
fn raw_step_returns_empty_and_non_empty_frames() {
    let config = serde_json::to_vec(&SimulationConfig {
        neuron_count: 2,
        connection_density: 0.0,
        ..SimulationConfig::default()
    })
    .unwrap();
    let mut handle = CcnSimulationHandle { id: 0 };
    let status = unsafe { ccn_create_simulation(config.as_ptr(), config.len(), &mut handle) };
    assert!(status.is_ok());

    let mut empty = empty_frame();
    let status = unsafe { ccn_raw_step(handle, std::ptr::null(), 0, 1, false, &mut empty) };
    assert!(status.is_ok());
    assert_eq!(empty.event_count, 0);
    assert!(empty.events.is_null());
    assert_eq!(empty.batch_spikes, 0);
    ccn_free_step_frame(empty);

    let input = serde_json::to_vec(&vec![serde_json::json!({
        "neuron_id": 0,
        "current": 2.0
    })])
    .unwrap();
    let mut non_empty = empty_frame();
    let status = unsafe {
        ccn_raw_step(
            handle,
            input.as_ptr(),
            input.len(),
            1,
            false,
            &mut non_empty,
        )
    };
    assert!(status.is_ok());
    assert_eq!(non_empty.event_count, 1);
    assert!(!non_empty.events.is_null());
    assert_eq!(non_empty.total_spikes, 1);
    assert_eq!(non_empty.batch_spikes, 1);
    assert_eq!(non_empty.active_neuron_count, 1);
    assert_eq!(non_empty.average_weight, 0.0);
    ccn_free_step_frame(non_empty);
    assert!(ccn_free_simulation(handle).is_ok());
}

#[test]
fn raw_snapshots_fall_back_to_host_network_without_experiment() {
    let config = serde_json::to_vec(&SimulationConfig {
        neuron_count: 2,
        connection_density: 0.0,
        ..SimulationConfig::default()
    })
    .unwrap();
    let mut handle = CcnSimulationHandle { id: 0 };
    assert!(unsafe { ccn_create_simulation(config.as_ptr(), config.len(), &mut handle) }.is_ok());

    let input = serde_json::to_vec(&vec![serde_json::json!({
        "neuron_id": 0,
        "current": 2.0
    })])
    .unwrap();
    let mut frame = empty_frame();
    assert!(
        unsafe { ccn_raw_step(handle, input.as_ptr(), input.len(), 1, false, &mut frame) }.is_ok()
    );
    ccn_free_step_frame(frame);

    let mut activity = CcnBuffer::empty();
    assert!(ccn_activity_snapshot(handle, &mut activity).is_ok());
    let activity_json = buffer_to_json(activity);
    ccn_free_buffer(activity);
    assert_eq!(activity_json["step"], 1);
    assert_eq!(activity_json["spiked"][0], true);

    let mut weights = CcnBuffer::empty();
    assert!(ccn_weight_snapshot(handle, &mut weights).is_ok());
    let weight_json = buffer_to_json(weights);
    ccn_free_buffer(weights);
    assert_eq!(weight_json["step"], 1);

    assert!(ccn_free_simulation(handle).is_ok());
}

#[test]
fn experiment_lifecycle_result_and_snapshots_are_buffers() {
    let config = serde_json::to_vec(&SimulationConfig::default()).unwrap();
    let mut handle = CcnSimulationHandle { id: 0 };
    assert!(unsafe { ccn_create_simulation(config.as_ptr(), config.len(), &mut handle) }.is_ok());

    let experiment = serde_json::to_vec(&pattern_recognition_preset(5)).unwrap();
    assert!(unsafe { ccn_load_experiment(handle, experiment.as_ptr(), experiment.len()) }.is_ok());
    let mut state = 0;
    assert!(ccn_experiment_state(handle, &mut state).is_ok());
    assert_eq!(state, 1);

    let mut progress = CcnPhaseProgress {
        phase_index: 0,
        phase_step: 0,
        phase_duration: 0,
        total_step: 0,
        total_duration: 0,
        progress: 0.0,
    };
    assert!(ccn_phase_progress(handle, &mut progress).is_ok());
    assert!(progress.total_duration > 0);

    loop {
        let mut frame = empty_frame();
        assert!(ccn_step_experiment(handle, 4, &mut frame).is_ok());
        ccn_free_step_frame(frame);
        assert!(ccn_experiment_state(handle, &mut state).is_ok());
        if state == 4 {
            break;
        }
    }

    let mut result = CcnBuffer::empty();
    assert!(ccn_experiment_result(handle, &mut result).is_ok());
    assert!(buffer_to_string(result).contains("pattern_recognition"));
    ccn_free_buffer(result);

    let mut activity = CcnBuffer::empty();
    assert!(ccn_activity_snapshot(handle, &mut activity).is_ok());
    assert!(buffer_to_string(activity).contains("membranes"));
    ccn_free_buffer(activity);

    let mut weights = CcnBuffer::empty();
    assert!(ccn_weight_snapshot(handle, &mut weights).is_ok());
    assert!(buffer_to_string(weights).contains("weights"));
    ccn_free_buffer(weights);

    assert!(ccn_free_simulation(handle).is_ok());
}

#[test]
fn experiment_step_updates_snapshots_from_runner_network() {
    let config = serde_json::to_vec(&SimulationConfig::default()).unwrap();
    let mut handle = CcnSimulationHandle { id: 0 };
    assert!(unsafe { ccn_create_simulation(config.as_ptr(), config.len(), &mut handle) }.is_ok());

    let experiment = serde_json::to_vec(&pattern_recognition_preset(9)).unwrap();
    assert!(unsafe { ccn_load_experiment(handle, experiment.as_ptr(), experiment.len()) }.is_ok());

    let mut frame = empty_frame();
    assert!(ccn_step_experiment(handle, 3, &mut frame).is_ok());
    assert_eq!(frame.steps, 3);
    ccn_free_step_frame(frame);

    let mut activity = CcnBuffer::empty();
    assert!(ccn_activity_snapshot(handle, &mut activity).is_ok());
    let activity_json = buffer_to_json(activity);
    ccn_free_buffer(activity);
    assert_eq!(activity_json["step"], 3);
    assert!(
        activity_json["recent_firing_rates"]
            .as_array()
            .unwrap()
            .iter()
            .any(|value| value.as_f64().unwrap() > 0.0)
    );

    let mut weights = CcnBuffer::empty();
    assert!(ccn_weight_snapshot(handle, &mut weights).is_ok());
    let weight_json = buffer_to_json(weights);
    ccn_free_buffer(weights);
    assert_eq!(weight_json["step"], 3);
    assert!(weight_json["average_weight"].as_f64().unwrap() > 0.0);

    assert!(ccn_free_simulation(handle).is_ok());
}

#[test]
fn experiment_step_frame_exposes_rust_statistics() {
    let config = serde_json::to_vec(&SimulationConfig::default()).unwrap();
    let mut handle = CcnSimulationHandle { id: 0 };
    assert!(unsafe { ccn_create_simulation(config.as_ptr(), config.len(), &mut handle) }.is_ok());

    let experiment = serde_json::to_vec(&pattern_recognition_preset(11)).unwrap();
    assert!(unsafe { ccn_load_experiment(handle, experiment.as_ptr(), experiment.len()) }.is_ok());

    let mut frame = empty_frame();
    assert!(ccn_step_experiment(handle, 4, &mut frame).is_ok());
    assert!(frame.event_count > 0);
    assert!(frame.total_spikes > 0);
    assert_eq!(frame.batch_spikes as usize, frame.event_count);
    assert!(frame.active_neuron_count > 0);
    assert!(frame.average_weight > 0.0);
    ccn_free_step_frame(frame);

    assert!(ccn_free_simulation(handle).is_ok());
}

#[test]
fn experiment_result_returns_custom_pattern_response_json() {
    let config = serde_json::to_vec(&SimulationConfig::default()).unwrap();
    let mut handle = CcnSimulationHandle { id: 0 };
    assert!(unsafe { ccn_create_simulation(config.as_ptr(), config.len(), &mut handle) }.is_ok());

    let experiment = serde_json::to_vec(&custom_pattern_definition()).unwrap();
    assert!(unsafe { ccn_load_experiment(handle, experiment.as_ptr(), experiment.len()) }.is_ok());

    let mut state = 0;
    while state != 4 {
        let mut frame = empty_frame();
        assert!(ccn_step_experiment(handle, 4, &mut frame).is_ok());
        ccn_free_step_frame(frame);
        assert!(ccn_experiment_state(handle, &mut state).is_ok());
    }

    let mut result = CcnBuffer::empty();
    assert!(ccn_experiment_result(handle, &mut result).is_ok());
    let result_json = buffer_to_json(result);
    ccn_free_buffer(result);

    assert_eq!(result_json["type"], "custom_pattern_response");
    assert_eq!(result_json["pattern_id"], "target");
    assert!(result_json["target_spike_count"].as_u64().unwrap() > 0);
    assert!(ccn_free_simulation(handle).is_ok());
}

fn empty_frame() -> CcnStepFrame {
    CcnStepFrame {
        start_step: 0,
        steps: 0,
        event_count: 0,
        events: std::ptr::null_mut(),
        total_spikes: 0,
        batch_spikes: 0,
        active_neuron_count: 0,
        average_weight: 0.0,
    }
}

fn buffer_to_json(buffer: CcnBuffer) -> Value {
    serde_json::from_str(&buffer_to_string(buffer)).unwrap()
}

fn buffer_to_string(buffer: CcnBuffer) -> String {
    if buffer.ptr.is_null() {
        return String::new();
    }
    let bytes = unsafe { slice::from_raw_parts(buffer.ptr, buffer.len) };
    String::from_utf8(bytes.to_vec()).unwrap()
}

fn custom_pattern_definition() -> ExperimentDefinition {
    let network = SimulationConfig {
        seed: Some(404),
        neuron_count: 16,
        connection_density: 0.0,
        inhibitory_fraction: 0.0,
        ..SimulationConfig::default()
    };
    ExperimentDefinition {
        schema_version: 1,
        preset_id: Some("custom_pattern_lab".to_string()),
        seed: Some(404),
        network,
        patterns: vec![Pattern::new("target", "Target", &[2, 5], 1.4)],
        phases: vec![
            Phase {
                id: "custom_train".to_string(),
                phase_type: PhaseType::Train,
                duration_steps: 3,
                learning_enabled: true,
                schedule: PatternSchedule::Constant {
                    pattern_id: "target".to_string(),
                    noise_probability: 0.2,
                },
                phase_seed: Some(1),
                stop_condition: None,
            },
            Phase {
                id: "custom_probe".to_string(),
                phase_type: PhaseType::Probe,
                duration_steps: 4,
                learning_enabled: false,
                schedule: PatternSchedule::Constant {
                    pattern_id: "target".to_string(),
                    noise_probability: 0.0,
                },
                phase_seed: Some(2),
                stop_condition: None,
            },
        ],
        metric_windows: Vec::<MetricWindow>::new(),
        result_config: ResultConfig {
            kind: ResultKind::CustomPatternResponse,
        },
    }
}

use ccn_simulation_core::experiments::{
    ExperimentRunner, ExperimentState, PatternSchedule, ResetMode, memory_echo_preset,
    pattern_recognition_preset,
};

#[test]
fn phase_transitions_complete_by_duration_and_report_progress() {
    let definition = pattern_recognition_preset(12);
    let total_duration: u32 = definition.phases.iter().map(|p| p.duration_steps).sum();
    let mut runner = ExperimentRunner::default();
    runner.load(definition).unwrap();

    while runner.state != ExperimentState::Completed {
        runner.step(1).unwrap();
    }

    let progress = runner.progress();
    assert_eq!(progress.total_step, total_duration);
    assert_eq!(progress.progress, 1.0);
}

#[test]
fn pattern_recognition_preset_returns_selectivity_shape() {
    let mut runner = ExperimentRunner::default();
    runner.load(pattern_recognition_preset(22)).unwrap();
    while runner.state != ExperimentState::Completed {
        runner.step(4).unwrap();
    }

    let result = serde_json::to_value(runner.result().unwrap()).unwrap();
    assert_eq!(result["type"], "pattern_recognition");
    assert!(result["a_selective_count"].is_u64());
    assert!(result["average_selectivity_score"].is_number());
}

#[test]
fn memory_echo_preset_returns_echo_shape() {
    let mut runner = ExperimentRunner::default();
    runner.load(memory_echo_preset(23)).unwrap();
    while runner.state != ExperimentState::Completed {
        runner.step(4).unwrap();
    }

    let result = serde_json::to_value(runner.result().unwrap()).unwrap();
    assert_eq!(result["type"], "memory_echo");
    assert!(result["decay_curve"].is_array());
    assert!(result["spontaneous_spike_rate"].is_number());
}

#[test]
fn noisy_input_is_deterministic_for_same_phase_seed() {
    let mut definition = pattern_recognition_preset(42);
    if let PatternSchedule::Constant {
        noise_probability, ..
    } = &mut definition.phases[0].schedule
    {
        *noise_probability = 0.5;
    }

    let mut first = ExperimentRunner::default();
    let mut second = ExperimentRunner::default();
    first.load(definition.clone()).unwrap();
    second.load(definition).unwrap();

    assert_eq!(
        first.step(8).unwrap().spikes,
        second.step(8).unwrap().spikes
    );
}

#[test]
fn seeded_full_recreate_reset_reproduces_frames_and_results() {
    let mut runner = ExperimentRunner::default();
    runner.load(pattern_recognition_preset(99)).unwrap();
    let mut first_events = Vec::new();
    while runner.state != ExperimentState::Completed {
        first_events.extend(runner.step(1).unwrap().spikes);
    }
    let first_result = serde_json::to_value(runner.result().unwrap()).unwrap();

    runner.reset(ResetMode::FullRecreateFromSeed).unwrap();
    let mut second_events = Vec::new();
    while runner.state != ExperimentState::Completed {
        second_events.extend(runner.step(1).unwrap().spikes);
    }
    let second_result = serde_json::to_value(runner.result().unwrap()).unwrap();

    assert_eq!(first_events, second_events);
    assert_eq!(first_result, second_result);
}

#[test]
fn experiment_validation_rejects_invalid_pattern_neuron_ids() {
    let mut definition = pattern_recognition_preset(1);
    definition.patterns[0].activations[0].neuron_id = definition.network.neuron_count;

    let error = definition
        .validate()
        .expect_err("invalid pattern neuron rejected");
    assert!(error.to_string().contains("invalid neuron_id"));
}

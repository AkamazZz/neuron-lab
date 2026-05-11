use ccn_simulation_core::SimulationConfig;
use ccn_simulation_core::core::SUPPORTED_SCHEMA_VERSION;
use ccn_simulation_core::experiments::{
    ExperimentDefinition, ExperimentRunner, ExperimentState, PatternSchedule, Phase, PhaseType,
    ResetMode, ResultConfig, ResultKind, memory_echo_preset, pattern_recognition_preset,
};
use ccn_simulation_core::metrics::MetricWindow;
use ccn_simulation_core::patterns::Pattern;

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
fn result_kind_serializes_custom_pattern_response() {
    let json = serde_json::to_value(ResultConfig {
        kind: ResultKind::CustomPatternResponse,
    })
    .unwrap();

    assert_eq!(json["kind"], "custom_pattern_response");
}

#[test]
fn custom_pattern_response_result_counts_probe_metrics() {
    let mut runner = ExperimentRunner::default();
    runner
        .load(custom_pattern_definition("target", &[2, 5], 1.4))
        .unwrap();
    while runner.state != ExperimentState::Completed {
        runner.step(4).unwrap();
    }

    let result = serde_json::to_value(runner.result().unwrap()).unwrap();

    assert_eq!(result["type"], "custom_pattern_response");
    assert_eq!(result["pattern_id"], "target");
    assert_eq!(result["pattern_label"], "Target");
    assert_eq!(result["neuron_ids"], serde_json::json!([2, 5]));
    assert!((result["strength"].as_f64().unwrap() - 1.4).abs() < 0.0001);
    assert!((result["dropout"].as_f64().unwrap() - 0.2).abs() < 0.0001);
    assert!(result["target_spike_count"].as_u64().unwrap() > 0);
    assert!(result["target_active_count"].as_u64().unwrap() > 0);
    assert!(result["off_pattern_spike_count"].is_u64());
    assert!(result["off_pattern_active_count"].is_u64());
    let similarity = result["response_similarity"].as_f64().unwrap();
    assert!((0.0..=1.0).contains(&similarity));
    assert!(result["total_spikes"].as_u64().unwrap() > 0);
    assert!(result["average_weight"].as_f64().unwrap() >= 0.0);
    assert!(
        result["explanation_facts"]
            .as_array()
            .unwrap()
            .iter()
            .any(|fact| fact.as_str().unwrap().contains("Rust phase frames"))
    );
}

#[test]
fn custom_pattern_response_result_identity_changes_with_probe_pattern() {
    let mut first = ExperimentRunner::default();
    first
        .load(custom_pattern_definition("target", &[1, 3], 1.4))
        .unwrap();
    while first.state != ExperimentState::Completed {
        first.step(4).unwrap();
    }

    let mut second = ExperimentRunner::default();
    second
        .load(custom_pattern_definition("alternate", &[6, 8], 1.4))
        .unwrap();
    while second.state != ExperimentState::Completed {
        second.step(4).unwrap();
    }

    let first_result = serde_json::to_value(first.result().unwrap()).unwrap();
    let second_result = serde_json::to_value(second.result().unwrap()).unwrap();

    assert_eq!(first_result["pattern_id"], "target");
    assert_eq!(second_result["pattern_id"], "alternate");
    assert_ne!(first_result["neuron_ids"], second_result["neuron_ids"]);
}

#[test]
fn custom_pattern_response_returns_graceful_unknown_without_probe() {
    let mut definition = custom_pattern_definition("target", &[2, 5], 1.4);
    definition
        .phases
        .retain(|phase| phase.phase_type != PhaseType::Probe);
    let mut runner = ExperimentRunner::default();
    runner.load(definition).unwrap();
    while runner.state != ExperimentState::Completed {
        runner.step(4).unwrap();
    }

    let result = serde_json::to_value(runner.result().unwrap()).unwrap();

    assert_eq!(result["type"], "custom_pattern_response");
    assert_eq!(result["pattern_id"], "");
    assert_eq!(result["target_spike_count"], 0);
    assert_eq!(result["off_pattern_spike_count"], 0);
    assert!(
        result["explanation_facts"]
            .as_array()
            .unwrap()
            .iter()
            .any(|fact| fact.as_str().unwrap().contains("no constant probe phase"))
    );
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

fn custom_pattern_definition(
    pattern_id: &str,
    neurons: &[usize],
    current: f32,
) -> ExperimentDefinition {
    let network = SimulationConfig {
        seed: Some(777),
        neuron_count: 16,
        connection_density: 0.0,
        inhibitory_fraction: 0.0,
        ..SimulationConfig::default()
    };
    let label = match pattern_id {
        "target" => "Target",
        "alternate" => "Alternate",
        _ => "Pattern",
    };
    ExperimentDefinition {
        schema_version: SUPPORTED_SCHEMA_VERSION,
        preset_id: Some("custom_pattern_lab".to_string()),
        seed: Some(777),
        network,
        patterns: vec![Pattern::new(pattern_id, label, neurons, current)],
        phases: vec![
            Phase {
                id: "custom_train".to_string(),
                phase_type: PhaseType::Train,
                duration_steps: 3,
                learning_enabled: true,
                schedule: PatternSchedule::Constant {
                    pattern_id: pattern_id.to_string(),
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
                    pattern_id: pattern_id.to_string(),
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

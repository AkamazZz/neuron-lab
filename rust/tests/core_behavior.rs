use ccn_simulation_core::core::SUPPORTED_SCHEMA_VERSION;
use ccn_simulation_core::simulation::{BatchStepOptions, NeuronType, StepInput};
use ccn_simulation_core::{LearningConfig, Network, SimulationConfig};

fn config(seed: u64) -> SimulationConfig {
    SimulationConfig {
        seed: Some(seed),
        neuron_count: 8,
        inhibitory_fraction: 0.25,
        connection_density: 0.3,
        ..SimulationConfig::default()
    }
}

#[test]
fn invalid_config_rejects_missing_seed_and_bad_ranges() {
    let invalid = SimulationConfig {
        schema_version: SUPPORTED_SCHEMA_VERSION + 1,
        seed: None,
        neuron_count: 1,
        connection_density: 1.2,
        ..SimulationConfig::default()
    };

    let error = invalid.validate().expect_err("invalid config rejected");
    let text = error.to_string();
    assert!(text.contains("unsupported schema_version"));
    assert!(text.contains("seed is required"));
    assert!(text.contains("neuron_count"));
    assert!(text.contains("connection_density"));
}

#[test]
fn fixed_seed_reproduces_sparse_topology_and_weights() {
    let first = Network::new(config(42)).unwrap();
    let second = Network::new(config(42)).unwrap();

    let first_edges = first
        .synapses
        .iter()
        .map(|s| (s.source, s.target, s.weight, s.inhibitory))
        .collect::<Vec<_>>();
    let second_edges = second
        .synapses
        .iter()
        .map(|s| (s.source, s.target, s.weight, s.inhibitory))
        .collect::<Vec<_>>();
    assert_eq!(first_edges, second_edges);
}

#[test]
fn inhibitory_percentage_density_and_no_self_connections_are_respected() {
    let network = Network::new(config(7)).unwrap();
    let inhibitory = network
        .neurons
        .iter()
        .filter(|n| n.neuron_type == NeuronType::Inhibitory)
        .count();

    assert_eq!(inhibitory, 2);
    assert!(network.synapses.iter().all(|s| s.source != s.target));
    assert!(network.synapses.iter().any(|s| s.inhibitory));
    assert!(network.synapses.iter().all(|s| {
        if s.inhibitory {
            s.weight <= 0.0
        } else {
            s.weight >= 0.0
        }
    }));
}

#[test]
fn threshold_spike_emits_batch_event_only() {
    let mut network = Network::new(SimulationConfig {
        seed: Some(1),
        neuron_count: 2,
        inhibitory_fraction: 0.0,
        connection_density: 0.0,
        ..SimulationConfig::default()
    })
    .unwrap();

    let frame = network.step_batch(BatchStepOptions {
        steps: 2,
        learning_enabled: false,
        input: vec![StepInput {
            neuron_id: 0,
            current: 1.2,
        }],
    });

    assert_eq!(frame.steps, 2);
    assert_eq!(frame.spikes.len(), 2);
    assert!(frame.spikes.iter().all(|event| event.neuron_id == 0));
}

#[test]
fn inhibitory_synapse_suppresses_activity_on_next_step() {
    let mut network = Network::new(SimulationConfig {
        seed: Some(1),
        neuron_count: 2,
        inhibitory_fraction: 0.5,
        connection_density: 0.0,
        threshold: 1.0,
        ..SimulationConfig::default()
    })
    .unwrap();
    network.add_synapse(0, 1, -0.7);
    network.neurons[0].membrane = 1.2;
    network.step_batch(BatchStepOptions::default());

    network.step_batch(BatchStepOptions {
        steps: 1,
        learning_enabled: false,
        input: vec![StepInput {
            neuron_id: 1,
            current: 0.6,
        }],
    });

    assert!(network.neurons[1].membrane < 0.0);
}

#[test]
fn stdp_strengthens_when_pre_spikes_before_post() {
    let mut network = Network::new(SimulationConfig {
        seed: Some(1),
        neuron_count: 2,
        inhibitory_fraction: 0.0,
        connection_density: 0.0,
        threshold: 1.0,
        learning: LearningConfig {
            potentiation_rate: 0.2,
            depression_rate: 0.1,
            ..LearningConfig::default()
        },
        ..SimulationConfig::default()
    })
    .unwrap();
    let edge = network.add_synapse(0, 1, 0.2);
    network.step_batch(BatchStepOptions {
        steps: 1,
        learning_enabled: true,
        input: vec![StepInput {
            neuron_id: 0,
            current: 1.2,
        }],
    });
    network.step_batch(BatchStepOptions {
        steps: 1,
        learning_enabled: true,
        input: vec![StepInput {
            neuron_id: 1,
            current: 1.2,
        }],
    });

    assert!(network.synapses[edge].weight > 0.2);
}

#[test]
fn stdp_weakens_when_post_spikes_before_pre() {
    let mut network = Network::new(SimulationConfig {
        seed: Some(1),
        neuron_count: 2,
        inhibitory_fraction: 0.0,
        connection_density: 0.0,
        threshold: 1.0,
        learning: LearningConfig {
            potentiation_rate: 0.2,
            depression_rate: 0.1,
            ..LearningConfig::default()
        },
        ..SimulationConfig::default()
    })
    .unwrap();
    let edge = network.add_synapse(0, 1, 0.5);
    network.step_batch(BatchStepOptions {
        steps: 1,
        learning_enabled: true,
        input: vec![StepInput {
            neuron_id: 1,
            current: 1.2,
        }],
    });
    network.step_batch(BatchStepOptions {
        steps: 1,
        learning_enabled: true,
        input: vec![StepInput {
            neuron_id: 0,
            current: 1.2,
        }],
    });

    assert!(network.synapses[edge].weight < 0.5);
}

#[test]
fn disabled_learning_preserves_weights() {
    let mut network = Network::new(SimulationConfig {
        seed: Some(1),
        neuron_count: 2,
        inhibitory_fraction: 0.0,
        connection_density: 0.0,
        ..SimulationConfig::default()
    })
    .unwrap();
    let edge = network.add_synapse(0, 1, 0.4);
    network.step_batch(BatchStepOptions {
        steps: 1,
        learning_enabled: false,
        input: vec![StepInput {
            neuron_id: 0,
            current: 1.2,
        }],
    });
    network.step_batch(BatchStepOptions {
        steps: 1,
        learning_enabled: false,
        input: vec![StepInput {
            neuron_id: 1,
            current: 1.2,
        }],
    });

    assert_eq!(network.synapses[edge].weight, 0.4);
}

#[test]
fn snapshots_and_metric_windows_report_current_state() {
    let mut network = Network::new(config(3)).unwrap();
    let frame = network.step_batch(BatchStepOptions {
        steps: 1,
        learning_enabled: false,
        input: vec![StepInput {
            neuron_id: 3,
            current: 2.0,
        }],
    });
    let activity = network.activity_snapshot();
    let weights = network.weight_snapshot();

    assert_eq!(frame.statistics.batch_spikes, 1);
    assert_eq!(activity.membranes.len(), network.neurons.len());
    assert_eq!(weights.weights.len(), network.synapses.len());
    assert!(weights.weights.iter().all(|w| w.source != w.target));
}

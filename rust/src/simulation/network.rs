use super::{EdgeId, Neuron, NeuronType, Synapse};
use crate::core::{SimulationConfig, ValidationError, seeded_rng};
use crate::patterns::{Pattern, PatternActivation};
use rand::Rng;
use serde::{Deserialize, Serialize};
use std::collections::HashSet;

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq)]
pub struct SpikeEvent {
    pub step_offset: u32,
    pub absolute_step: u64,
    pub neuron_id: u32,
    pub membrane: f32,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Default)]
pub struct StepFrame {
    pub start_step: u64,
    pub steps: u32,
    pub spikes: Vec<SpikeEvent>,
    pub statistics: SpikeStatistics,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Default)]
pub struct SpikeStatistics {
    pub total_spikes: u64,
    pub batch_spikes: u32,
    pub active_neuron_count: u32,
    pub average_weight: f32,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq)]
pub struct StepInput {
    pub neuron_id: usize,
    pub current: f32,
}

impl From<&PatternActivation> for StepInput {
    fn from(value: &PatternActivation) -> Self {
        Self {
            neuron_id: value.neuron_id,
            current: value.current,
        }
    }
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq)]
pub struct BatchStepOptions {
    pub steps: u32,
    pub learning_enabled: bool,
    pub input: Vec<StepInput>,
}

impl Default for BatchStepOptions {
    fn default() -> Self {
        Self {
            steps: 1,
            learning_enabled: true,
            input: Vec::new(),
        }
    }
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq)]
pub struct ActivitySnapshot {
    pub step: u64,
    pub membranes: Vec<f32>,
    pub recent_firing_rates: Vec<f32>,
    pub spiked: Vec<bool>,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq)]
pub struct WeightSample {
    pub source: u32,
    pub target: u32,
    pub weight: f32,
    pub inhibitory: bool,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq)]
pub struct SparseWeightSnapshot {
    pub step: u64,
    pub weights: Vec<WeightSample>,
    pub average_weight: f32,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct Network {
    pub config: SimulationConfig,
    pub neurons: Vec<Neuron>,
    pub synapses: Vec<Synapse>,
    pub outgoing_edges: Vec<Vec<EdgeId>>,
    pub incoming_edges: Vec<Vec<EdgeId>>,
    pub step: u64,
    pub total_spikes: u64,
    previous_spikes: Vec<usize>,
}

impl Network {
    pub fn new(config: SimulationConfig) -> Result<Self, ValidationError> {
        config.validate()?;
        let mut rng = seeded_rng(config.seed(), 0);
        let inhibitory_count =
            ((config.neuron_count as f32) * config.inhibitory_fraction).round() as usize;
        let neurons = (0..config.neuron_count)
            .map(|id| {
                let neuron_type = if id < inhibitory_count {
                    NeuronType::Inhibitory
                } else {
                    NeuronType::Excitatory
                };
                Neuron::new(id, neuron_type)
            })
            .collect::<Vec<_>>();

        let mut network = Self {
            outgoing_edges: vec![Vec::new(); config.neuron_count],
            incoming_edges: vec![Vec::new(); config.neuron_count],
            neurons,
            synapses: Vec::new(),
            step: 0,
            total_spikes: 0,
            previous_spikes: Vec::new(),
            config,
        };

        for source in 0..network.config.neuron_count {
            for target in 0..network.config.neuron_count {
                if source == target || rng.random::<f32>() > network.config.connection_density {
                    continue;
                }
                let source_type = network.neurons[source].neuron_type;
                let weight = if source_type == NeuronType::Inhibitory {
                    -rng.random_range(0.05..=network.config.max_inhibitory_weight)
                } else {
                    rng.random_range(
                        network.config.min_excitatory_weight..=network.config.max_excitatory_weight,
                    )
                };
                network.add_synapse(source, target, weight);
            }
        }
        Ok(network)
    }

    pub fn add_synapse(&mut self, source: usize, target: usize, weight: f32) -> EdgeId {
        let id = self.synapses.len();
        let synapse = Synapse::new(
            id,
            source,
            target,
            self.neurons[source].neuron_type,
            weight,
            &self.config,
        );
        self.synapses.push(synapse);
        self.outgoing_edges[source].push(id);
        self.incoming_edges[target].push(id);
        id
    }

    pub fn reset_state(&mut self) {
        for neuron in &mut self.neurons {
            neuron.membrane = 0.0;
            neuron.recovery = 0.0;
            neuron.spiked = false;
            neuron.recent_firing_rate = 0.0;
            neuron.homeostasis_scale = 1.0;
            neuron.last_spike_step = None;
        }
        for synapse in &mut self.synapses {
            synapse.pre_trace = 0.0;
            synapse.post_trace = 0.0;
        }
        self.step = 0;
        self.total_spikes = 0;
        self.previous_spikes.clear();
    }

    pub fn recreate_from_seed(&self) -> Result<Self, ValidationError> {
        Self::new(self.config.clone())
    }

    pub fn step_pattern(&mut self, pattern: Option<&Pattern>, learning_enabled: bool) -> StepFrame {
        let input = pattern
            .map(|pattern| pattern.activations.iter().map(StepInput::from).collect())
            .unwrap_or_default();
        self.step_batch(BatchStepOptions {
            steps: 1,
            learning_enabled,
            input,
        })
    }

    pub fn step_batch(&mut self, options: BatchStepOptions) -> StepFrame {
        let start_step = self.step;
        let steps = options.steps.max(1);
        let mut spikes = Vec::new();
        for offset in 0..steps {
            let step_spikes = self.step_once(&options.input, options.learning_enabled);
            for neuron_id in step_spikes {
                spikes.push(SpikeEvent {
                    step_offset: offset,
                    absolute_step: self.step - 1,
                    neuron_id: neuron_id as u32,
                    membrane: self.neurons[neuron_id].membrane,
                });
            }
        }
        let active_neuron_count = spikes
            .iter()
            .map(|event| event.neuron_id)
            .collect::<HashSet<_>>()
            .len() as u32;
        StepFrame {
            start_step,
            steps,
            statistics: SpikeStatistics {
                total_spikes: self.total_spikes,
                batch_spikes: spikes.len() as u32,
                active_neuron_count,
                average_weight: self.average_weight(),
            },
            spikes,
        }
    }

    fn step_once(&mut self, input: &[StepInput], learning_enabled: bool) -> Vec<usize> {
        let mut currents = vec![0.0; self.neurons.len()];
        for external in input {
            if external.neuron_id < currents.len() {
                currents[external.neuron_id] += external.current;
            }
        }
        for &source in &self.previous_spikes {
            for &edge_id in &self.outgoing_edges[source] {
                let synapse = &self.synapses[edge_id];
                currents[synapse.target] += synapse.weight;
            }
        }

        let mut spikes = Vec::new();
        for neuron in &mut self.neurons {
            let recovery_drag = neuron.recovery * neuron.homeostasis_scale;
            neuron.membrane =
                neuron.membrane * self.config.membrane_decay + currents[neuron.id] - recovery_drag;
            neuron.spiked = neuron.membrane >= self.config.threshold;
            if neuron.spiked {
                spikes.push(neuron.id);
                neuron.membrane = self.config.reset_potential;
                neuron.recovery += self.config.adaptation_increment;
            } else {
                neuron.recovery *= self.config.recovery_decay;
            }
            let spike_sample = if neuron.spiked { 1.0 } else { 0.0 };
            neuron.recent_firing_rate = neuron.recent_firing_rate * 0.9 + spike_sample * 0.1;
        }

        if learning_enabled && self.config.learning.enabled {
            self.apply_stdp(&spikes);
        }
        for &neuron_id in &spikes {
            self.neurons[neuron_id].last_spike_step = Some(self.step);
        }
        for synapse in &mut self.synapses {
            synapse.pre_trace *= self.config.learning.trace_decay;
            synapse.post_trace *= self.config.learning.trace_decay;
        }
        for &neuron_id in &spikes {
            for &edge_id in &self.outgoing_edges[neuron_id] {
                self.synapses[edge_id].pre_trace = 1.0;
            }
            for &edge_id in &self.incoming_edges[neuron_id] {
                self.synapses[edge_id].post_trace = 1.0;
            }
        }
        self.previous_spikes = spikes.clone();
        self.total_spikes += spikes.len() as u64;
        self.step += 1;
        spikes
    }

    fn apply_stdp(&mut self, spikes: &[usize]) {
        let spiked = spikes.iter().copied().collect::<HashSet<_>>();
        let now = self.step;
        for synapse in &mut self.synapses {
            if synapse.inhibitory {
                continue;
            }
            let pre_now = spiked.contains(&synapse.source);
            let post_now = spiked.contains(&synapse.target);
            if post_now {
                if let Some(pre_step) = self.neurons[synapse.source].last_spike_step {
                    let delta = now.saturating_sub(pre_step);
                    if (1..=self.config.learning.positive_window_steps as u64).contains(&delta) {
                        synapse.weight += self.config.learning.potentiation_rate;
                    }
                }
            }
            if pre_now {
                if let Some(post_step) = self.neurons[synapse.target].last_spike_step {
                    let delta = now.saturating_sub(post_step);
                    if (1..=self.config.learning.negative_window_steps as u64).contains(&delta) {
                        synapse.weight -= self.config.learning.depression_rate;
                    }
                }
            }
            if pre_now && !post_now && synapse.post_trace < 0.01 {
                synapse.weight -= self.config.learning.depression_rate * 0.1;
            }
            synapse.clamp(&self.config);
        }
    }

    pub fn activity_snapshot(&self) -> ActivitySnapshot {
        ActivitySnapshot {
            step: self.step,
            membranes: self.neurons.iter().map(|n| n.membrane).collect(),
            recent_firing_rates: self.neurons.iter().map(|n| n.recent_firing_rate).collect(),
            spiked: self.neurons.iter().map(|n| n.spiked).collect(),
        }
    }

    pub fn weight_snapshot(&self) -> SparseWeightSnapshot {
        SparseWeightSnapshot {
            step: self.step,
            weights: self
                .synapses
                .iter()
                .map(|synapse| WeightSample {
                    source: synapse.source as u32,
                    target: synapse.target as u32,
                    weight: synapse.weight,
                    inhibitory: synapse.inhibitory,
                })
                .collect(),
            average_weight: self.average_weight(),
        }
    }

    pub fn average_weight(&self) -> f32 {
        if self.synapses.is_empty() {
            return 0.0;
        }
        self.synapses
            .iter()
            .map(|synapse| synapse.weight.abs())
            .sum::<f32>()
            / self.synapses.len() as f32
    }
}

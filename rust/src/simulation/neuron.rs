use serde::{Deserialize, Serialize};

#[derive(Clone, Copy, Debug, Serialize, Deserialize, PartialEq, Eq)]
#[repr(u8)]
pub enum NeuronType {
    Excitatory = 0,
    Inhibitory = 1,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq)]
pub struct Neuron {
    pub id: usize,
    pub neuron_type: NeuronType,
    pub membrane: f32,
    pub recovery: f32,
    pub spiked: bool,
    pub recent_firing_rate: f32,
    pub homeostasis_scale: f32,
    pub last_spike_step: Option<u64>,
}

impl Neuron {
    pub fn new(id: usize, neuron_type: NeuronType) -> Self {
        Self {
            id,
            neuron_type,
            membrane: 0.0,
            recovery: 0.0,
            spiked: false,
            recent_firing_rate: 0.0,
            homeostasis_scale: 1.0,
            last_spike_step: None,
        }
    }
}

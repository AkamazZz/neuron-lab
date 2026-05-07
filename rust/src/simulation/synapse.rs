use super::NeuronType;
use crate::core::SimulationConfig;
use serde::{Deserialize, Serialize};

pub type EdgeId = usize;

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq)]
pub struct Synapse {
    pub id: EdgeId,
    pub source: usize,
    pub target: usize,
    pub weight: f32,
    pub inhibitory: bool,
    pub pre_trace: f32,
    pub post_trace: f32,
}

impl Synapse {
    pub fn new(
        id: EdgeId,
        source: usize,
        target: usize,
        source_type: NeuronType,
        weight: f32,
        config: &SimulationConfig,
    ) -> Self {
        let inhibitory = source_type == NeuronType::Inhibitory;
        let mut synapse = Self {
            id,
            source,
            target,
            weight,
            inhibitory,
            pre_trace: 0.0,
            post_trace: 0.0,
        };
        synapse.clamp(config);
        synapse
    }

    pub fn clamp(&mut self, config: &SimulationConfig) {
        if self.inhibitory {
            self.weight = self.weight.clamp(-config.max_inhibitory_weight, 0.0);
        } else {
            self.weight = self
                .weight
                .clamp(config.min_excitatory_weight, config.max_excitatory_weight);
        }
    }
}

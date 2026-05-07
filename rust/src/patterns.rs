use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq)]
pub struct Pattern {
    pub id: String,
    pub label: String,
    pub activations: Vec<PatternActivation>,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq)]
pub struct PatternActivation {
    pub neuron_id: usize,
    pub current: f32,
}

impl Pattern {
    pub fn new(
        id: impl Into<String>,
        label: impl Into<String>,
        neurons: &[usize],
        current: f32,
    ) -> Self {
        Self {
            id: id.into(),
            label: label.into(),
            activations: neurons
                .iter()
                .copied()
                .map(|neuron_id| PatternActivation { neuron_id, current })
                .collect(),
        }
    }
}

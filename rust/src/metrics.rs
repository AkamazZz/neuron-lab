use crate::simulation::{ActivitySnapshot, StepFrame};
use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Default)]
pub struct MetricWindow {
    pub id: String,
    pub phase_id: String,
    pub start_step: u32,
    pub duration_steps: u32,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Default)]
pub struct MetricAccumulator {
    pub frames: Vec<StepFrame>,
    pub snapshots: Vec<ActivitySnapshot>,
}

impl MetricAccumulator {
    pub fn record(&mut self, frame: StepFrame, snapshot: ActivitySnapshot) {
        self.frames.push(frame);
        self.snapshots.push(snapshot);
    }

    pub fn spike_count_for_neuron(&self, neuron_id: u32) -> u32 {
        self.frames
            .iter()
            .flat_map(|frame| frame.spikes.iter())
            .filter(|event| event.neuron_id == neuron_id)
            .count() as u32
    }

    pub fn decay_curve(&self) -> Vec<f32> {
        self.snapshots
            .iter()
            .map(|snapshot| {
                snapshot.recent_firing_rates.iter().copied().sum::<f32>()
                    / snapshot.recent_firing_rates.len().max(1) as f32
            })
            .collect()
    }
}

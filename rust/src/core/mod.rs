use rand::SeedableRng;
use rand_chacha::ChaCha8Rng;
use serde::{Deserialize, Serialize};
use thiserror::Error;

pub const SUPPORTED_SCHEMA_VERSION: u32 = 1;

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq)]
#[serde(default)]
pub struct SimulationConfig {
    pub schema_version: u32,
    pub seed: Option<u64>,
    pub neuron_count: usize,
    pub inhibitory_fraction: f32,
    pub connection_density: f32,
    pub threshold: f32,
    pub reset_potential: f32,
    pub membrane_decay: f32,
    pub recovery_decay: f32,
    pub adaptation_increment: f32,
    pub min_excitatory_weight: f32,
    pub max_excitatory_weight: f32,
    pub max_inhibitory_weight: f32,
    pub learning: LearningConfig,
    pub noise: NoiseConfig,
}

impl Default for SimulationConfig {
    fn default() -> Self {
        Self {
            schema_version: SUPPORTED_SCHEMA_VERSION,
            seed: Some(1),
            neuron_count: 32,
            inhibitory_fraction: 0.2,
            connection_density: 0.15,
            threshold: 1.0,
            reset_potential: 0.0,
            membrane_decay: 0.9,
            recovery_decay: 0.95,
            adaptation_increment: 0.05,
            min_excitatory_weight: 0.05,
            max_excitatory_weight: 0.8,
            max_inhibitory_weight: 0.8,
            learning: LearningConfig::default(),
            noise: NoiseConfig::default(),
        }
    }
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq)]
#[serde(default)]
pub struct LearningConfig {
    pub enabled: bool,
    pub potentiation_rate: f32,
    pub depression_rate: f32,
    pub positive_window_steps: u32,
    pub negative_window_steps: u32,
    pub trace_decay: f32,
}

impl Default for LearningConfig {
    fn default() -> Self {
        Self {
            enabled: true,
            potentiation_rate: 0.04,
            depression_rate: 0.025,
            positive_window_steps: 6,
            negative_window_steps: 6,
            trace_decay: 0.9,
        }
    }
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq)]
#[serde(default)]
pub struct NoiseConfig {
    pub input_noise_probability: f32,
    pub input_noise_amplitude: f32,
}

impl Default for NoiseConfig {
    fn default() -> Self {
        Self {
            input_noise_probability: 0.0,
            input_noise_amplitude: 0.0,
        }
    }
}

#[derive(Clone, Debug, Error, PartialEq, Eq)]
pub enum ValidationError {
    #[error("{0}")]
    Message(String),
}

impl SimulationConfig {
    pub fn validate(&self) -> Result<(), ValidationError> {
        let mut errors = Vec::new();
        if self.schema_version != SUPPORTED_SCHEMA_VERSION {
            errors.push(format!(
                "unsupported schema_version {}, expected {}",
                self.schema_version, SUPPORTED_SCHEMA_VERSION
            ));
        }
        if self.seed.is_none() {
            errors.push("seed is required".to_string());
        }
        if !(2..=4096).contains(&self.neuron_count) {
            errors.push("neuron_count must be between 2 and 4096".to_string());
        }
        push_range(
            &mut errors,
            "inhibitory_fraction",
            self.inhibitory_fraction,
            0.0,
            1.0,
        );
        push_range(
            &mut errors,
            "connection_density",
            self.connection_density,
            0.0,
            1.0,
        );
        if self.threshold <= 0.0 || !self.threshold.is_finite() {
            errors.push("threshold must be finite and > 0".to_string());
        }
        push_range(&mut errors, "membrane_decay", self.membrane_decay, 0.0, 1.0);
        push_range(&mut errors, "recovery_decay", self.recovery_decay, 0.0, 1.0);
        if self.min_excitatory_weight < 0.0
            || self.max_excitatory_weight <= self.min_excitatory_weight
        {
            errors.push("excitatory weights must satisfy 0 <= min < max".to_string());
        }
        if self.max_inhibitory_weight <= 0.0 || !self.max_inhibitory_weight.is_finite() {
            errors.push("max_inhibitory_weight must be finite and > 0".to_string());
        }
        push_range(
            &mut errors,
            "learning.trace_decay",
            self.learning.trace_decay,
            0.0,
            1.0,
        );
        if self.learning.potentiation_rate < 0.0 || self.learning.depression_rate < 0.0 {
            errors.push("learning rates must be >= 0".to_string());
        }
        if self.learning.positive_window_steps == 0 || self.learning.negative_window_steps == 0 {
            errors.push("STDP windows must be > 0".to_string());
        }
        push_range(
            &mut errors,
            "noise.input_noise_probability",
            self.noise.input_noise_probability,
            0.0,
            1.0,
        );
        if self.noise.input_noise_amplitude < 0.0 || !self.noise.input_noise_amplitude.is_finite() {
            errors.push("noise.input_noise_amplitude must be finite and >= 0".to_string());
        }
        if errors.is_empty() {
            Ok(())
        } else {
            Err(ValidationError::Message(errors.join("; ")))
        }
    }

    pub fn seed(&self) -> u64 {
        self.seed.expect("validated config has seed")
    }
}

pub fn seeded_rng(seed: u64, phase_seed: u64) -> ChaCha8Rng {
    ChaCha8Rng::seed_from_u64(seed ^ phase_seed.rotate_left(17) ^ 0x9E37_79B9_7F4A_7C15)
}

fn push_range(errors: &mut Vec<String>, name: &str, value: f32, min: f32, max: f32) {
    if !value.is_finite() || value < min || value > max {
        errors.push(format!("{name} must be finite and between {min} and {max}"));
    }
}

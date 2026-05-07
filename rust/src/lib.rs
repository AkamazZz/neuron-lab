pub mod core;
pub mod experiments;
pub mod ffi;
pub mod metrics;
pub mod patterns;
pub mod simulation;

pub use crate::core::{LearningConfig, NoiseConfig, SimulationConfig, ValidationError};
pub use crate::experiments::{
    ExperimentDefinition, ExperimentRunner, ExperimentState, MemoryEchoResult,
    PatternRecognitionResult, PresetResult,
};
pub use crate::patterns::Pattern;
pub use crate::simulation::{Network, StepFrame};

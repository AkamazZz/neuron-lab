use crate::core::{SUPPORTED_SCHEMA_VERSION, SimulationConfig, ValidationError, seeded_rng};
use crate::metrics::{MetricAccumulator, MetricWindow};
use crate::patterns::{Pattern, PatternActivation};
use crate::simulation::{BatchStepOptions, Network, StepFrame, StepInput};
use rand::Rng;
use serde::{Deserialize, Serialize};
use std::collections::{HashMap, HashSet};

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq)]
pub struct ExperimentDefinition {
    pub schema_version: u32,
    pub preset_id: Option<String>,
    pub seed: Option<u64>,
    pub network: SimulationConfig,
    pub patterns: Vec<Pattern>,
    pub phases: Vec<Phase>,
    pub metric_windows: Vec<MetricWindow>,
    pub result_config: ResultConfig,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Default)]
pub struct ResultConfig {
    pub kind: ResultKind,
}

#[derive(Clone, Copy, Debug, Serialize, Deserialize, PartialEq, Eq, Default)]
#[serde(rename_all = "snake_case")]
pub enum ResultKind {
    #[default]
    Generic,
    PatternRecognition,
    MemoryEcho,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq)]
pub struct Phase {
    pub id: String,
    pub phase_type: PhaseType,
    pub duration_steps: u32,
    pub learning_enabled: bool,
    pub schedule: PatternSchedule,
    pub phase_seed: Option<u64>,
    pub stop_condition: Option<StopCondition>,
}

#[derive(Clone, Copy, Debug, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum PhaseType {
    Train,
    Probe,
    Silence,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq)]
#[serde(tag = "type", rename_all = "snake_case")]
pub enum PatternSchedule {
    Constant {
        pattern_id: String,
        noise_probability: f32,
    },
    Sequence {
        pattern_ids: Vec<String>,
        noise_probability: f32,
    },
    Silence,
    Generated {
        generator_id: String,
    },
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq)]
pub struct StopCondition {
    pub max_spikes: Option<u32>,
}

#[derive(Clone, Copy, Debug, Serialize, Deserialize, PartialEq, Eq)]
#[repr(u32)]
pub enum ExperimentState {
    Idle = 0,
    Loaded = 1,
    Running = 2,
    Paused = 3,
    Completed = 4,
    Failed = 5,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Default)]
pub struct PhaseProgress {
    pub phase_index: u32,
    pub phase_step: u32,
    pub phase_duration: u32,
    pub total_step: u32,
    pub total_duration: u32,
    pub progress: f32,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq)]
#[serde(tag = "type", rename_all = "snake_case")]
pub enum PresetResult {
    Generic {
        total_spikes: u64,
        average_weight: f32,
    },
    PatternRecognition(PatternRecognitionResult),
    MemoryEcho(MemoryEchoResult),
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq)]
pub struct PatternRecognitionResult {
    pub a_selective_count: u32,
    pub b_selective_count: u32,
    pub mixed_count: u32,
    pub silent_count: u32,
    pub average_selectivity_score: f32,
    pub explanation_facts: Vec<String>,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq)]
pub struct MemoryEchoResult {
    pub echo_duration_steps: u32,
    pub decay_curve: Vec<f32>,
    pub remaining_active_neuron_count: u32,
    pub spontaneous_spike_rate: f32,
    pub explanation_facts: Vec<String>,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct ExperimentRunner {
    pub state: ExperimentState,
    pub definition: Option<ExperimentDefinition>,
    pub network: Option<Network>,
    pub phase_index: usize,
    pub phase_step: u32,
    pub total_step: u32,
    pub last_error: Option<String>,
    metrics: MetricAccumulator,
    phase_frames: HashMap<String, Vec<StepFrame>>,
}

#[derive(Clone, Copy, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub enum ResetMode {
    NetworkOnly,
    NetworkAndExperiment,
    FullRecreateFromSeed,
}

impl Default for ExperimentRunner {
    fn default() -> Self {
        Self {
            state: ExperimentState::Idle,
            definition: None,
            network: None,
            phase_index: 0,
            phase_step: 0,
            total_step: 0,
            last_error: None,
            metrics: MetricAccumulator::default(),
            phase_frames: HashMap::new(),
        }
    }
}

impl ExperimentDefinition {
    pub fn validate(&self) -> Result<(), ValidationError> {
        let mut errors = Vec::new();
        if self.schema_version != SUPPORTED_SCHEMA_VERSION {
            errors.push("unsupported experiment schema_version".to_string());
        }
        if self.seed.is_none() {
            errors.push("experiment seed is required".to_string());
        }
        if self.patterns.is_empty() {
            errors.push("at least one pattern is required".to_string());
        }
        if self.phases.is_empty() {
            errors.push("at least one phase is required".to_string());
        }
        if let Err(error) = self.network.validate() {
            errors.push(error.to_string());
        }
        let pattern_ids = self
            .patterns
            .iter()
            .map(|pattern| pattern.id.as_str())
            .collect::<HashSet<_>>();
        for pattern in &self.patterns {
            if pattern.activations.is_empty() {
                errors.push(format!("pattern {} has no activations", pattern.id));
            }
            for activation in &pattern.activations {
                if activation.neuron_id >= self.network.neuron_count {
                    errors.push(format!(
                        "pattern {} uses invalid neuron_id {}",
                        pattern.id, activation.neuron_id
                    ));
                }
            }
        }
        for phase in &self.phases {
            if phase.duration_steps == 0 {
                errors.push(format!("phase {} duration_steps must be > 0", phase.id));
            }
            validate_schedule(&mut errors, &pattern_ids, phase);
        }
        for window in &self.metric_windows {
            if window.duration_steps == 0 {
                errors.push(format!(
                    "metric window {} duration_steps must be > 0",
                    window.id
                ));
            }
            if !self.phases.iter().any(|phase| phase.id == window.phase_id) {
                errors.push(format!(
                    "metric window {} references unknown phase",
                    window.id
                ));
            }
        }
        if errors.is_empty() {
            Ok(())
        } else {
            Err(ValidationError::Message(errors.join("; ")))
        }
    }
}

fn validate_schedule(errors: &mut Vec<String>, pattern_ids: &HashSet<&str>, phase: &Phase) {
    match &phase.schedule {
        PatternSchedule::Constant {
            pattern_id,
            noise_probability,
        } => {
            if !pattern_ids.contains(pattern_id.as_str()) {
                errors.push(format!("phase {} references unknown pattern", phase.id));
            }
            validate_noise(errors, *noise_probability, &phase.id);
        }
        PatternSchedule::Sequence {
            pattern_ids: ids,
            noise_probability,
        } => {
            if ids.is_empty() {
                errors.push(format!("phase {} sequence must not be empty", phase.id));
            }
            for pattern_id in ids {
                if !pattern_ids.contains(pattern_id.as_str()) {
                    errors.push(format!("phase {} references unknown pattern", phase.id));
                }
            }
            validate_noise(errors, *noise_probability, &phase.id);
        }
        PatternSchedule::Silence => {}
        PatternSchedule::Generated { .. } => {}
    }
}

fn validate_noise(errors: &mut Vec<String>, probability: f32, phase_id: &str) {
    if !probability.is_finite() || !(0.0..=1.0).contains(&probability) {
        errors.push(format!("phase {phase_id} noise_probability must be 0..1"));
    }
}

impl ExperimentRunner {
    pub fn load(&mut self, definition: ExperimentDefinition) -> Result<(), ValidationError> {
        definition.validate()?;
        self.network = Some(Network::new(definition.network.clone())?);
        self.definition = Some(definition);
        self.state = ExperimentState::Loaded;
        self.phase_index = 0;
        self.phase_step = 0;
        self.total_step = 0;
        self.last_error = None;
        self.metrics = MetricAccumulator::default();
        self.phase_frames.clear();
        Ok(())
    }

    pub fn clear(&mut self) {
        *self = Self::default();
    }

    pub fn reset(&mut self, mode: ResetMode) -> Result<(), ValidationError> {
        match mode {
            ResetMode::NetworkOnly => {
                if let Some(network) = &mut self.network {
                    network.reset_state();
                }
            }
            ResetMode::NetworkAndExperiment => {
                if let Some(network) = &mut self.network {
                    network.reset_state();
                }
                self.phase_index = 0;
                self.phase_step = 0;
                self.total_step = 0;
                self.state = ExperimentState::Loaded;
                self.metrics = MetricAccumulator::default();
                self.phase_frames.clear();
            }
            ResetMode::FullRecreateFromSeed => {
                if let Some(definition) = self.definition.clone() {
                    self.load(definition)?;
                }
            }
        }
        Ok(())
    }

    pub fn step(&mut self, max_steps: u32) -> Result<StepFrame, ValidationError> {
        if matches!(self.state, ExperimentState::Completed) {
            return Ok(StepFrame::default());
        }
        if !matches!(
            self.state,
            ExperimentState::Loaded | ExperimentState::Running
        ) {
            return Err(ValidationError::Message(
                "experiment must be loaded before stepping".to_string(),
            ));
        }
        self.state = ExperimentState::Running;
        let mut merged = StepFrame {
            start_step: self.total_step as u64,
            steps: 0,
            spikes: Vec::new(),
            statistics: Default::default(),
        };
        for _ in 0..max_steps.max(1) {
            if self.state == ExperimentState::Completed {
                break;
            }
            let frame = self.step_active_phase()?;
            merged.steps += frame.steps;
            merged.spikes.extend(frame.spikes);
            merged.statistics = frame.statistics;
        }
        Ok(merged)
    }

    fn step_active_phase(&mut self) -> Result<StepFrame, ValidationError> {
        let definition = self
            .definition
            .as_ref()
            .ok_or_else(|| ValidationError::Message("no experiment loaded".to_string()))?;
        let phase = definition
            .phases
            .get(self.phase_index)
            .ok_or_else(|| ValidationError::Message("phase index out of range".to_string()))?
            .clone();
        let input = self.phase_input(definition, &phase);
        let network = self
            .network
            .as_mut()
            .ok_or_else(|| ValidationError::Message("network missing".to_string()))?;
        let frame = network.step_batch(BatchStepOptions {
            steps: 1,
            learning_enabled: phase.learning_enabled,
            input,
        });
        self.metrics
            .record(frame.clone(), network.activity_snapshot());
        self.phase_frames
            .entry(phase.id.clone())
            .or_default()
            .push(frame.clone());
        self.phase_step += 1;
        self.total_step += 1;
        if self.phase_step >= phase.duration_steps
            || phase
                .stop_condition
                .as_ref()
                .and_then(|stop| stop.max_spikes)
                .is_some_and(|max| frame.statistics.batch_spikes >= max)
        {
            self.phase_index += 1;
            self.phase_step = 0;
            if self.phase_index >= definition.phases.len() {
                self.state = ExperimentState::Completed;
            }
        }
        Ok(frame)
    }

    fn phase_input(&self, definition: &ExperimentDefinition, phase: &Phase) -> Vec<StepInput> {
        let pattern_map = definition
            .patterns
            .iter()
            .map(|pattern| (pattern.id.as_str(), pattern))
            .collect::<HashMap<_, _>>();
        let maybe_pattern = match &phase.schedule {
            PatternSchedule::Constant { pattern_id, .. } => {
                pattern_map.get(pattern_id.as_str()).copied()
            }
            PatternSchedule::Sequence { pattern_ids, .. } => {
                let index = self.phase_step as usize % pattern_ids.len().max(1);
                pattern_ids
                    .get(index)
                    .and_then(|id| pattern_map.get(id.as_str()))
                    .copied()
            }
            PatternSchedule::Silence => None,
            PatternSchedule::Generated { .. } => None,
        };
        let noise_probability = match &phase.schedule {
            PatternSchedule::Constant {
                noise_probability, ..
            }
            | PatternSchedule::Sequence {
                noise_probability, ..
            } => *noise_probability,
            _ => 0.0,
        };
        let mut input = maybe_pattern
            .map(|pattern| {
                pattern
                    .activations
                    .iter()
                    .map(StepInput::from)
                    .collect::<Vec<_>>()
            })
            .unwrap_or_default();
        if noise_probability > 0.0 {
            let mut rng = seeded_rng(
                definition.seed.expect("validated experiment seed"),
                phase.phase_seed.unwrap_or(0) ^ self.phase_step as u64,
            );
            for item in &mut input {
                if rng.random::<f32>() < noise_probability {
                    item.current = 0.0;
                }
            }
        }
        input
    }

    pub fn progress(&self) -> PhaseProgress {
        let total_duration = self
            .definition
            .as_ref()
            .map(|definition| {
                definition
                    .phases
                    .iter()
                    .map(|phase| phase.duration_steps)
                    .sum()
            })
            .unwrap_or(0);
        let phase_duration = self
            .definition
            .as_ref()
            .and_then(|definition| definition.phases.get(self.phase_index))
            .map(|phase| phase.duration_steps)
            .unwrap_or(0);
        PhaseProgress {
            phase_index: self.phase_index as u32,
            phase_step: self.phase_step,
            phase_duration,
            total_step: self.total_step,
            total_duration,
            progress: if total_duration == 0 {
                0.0
            } else {
                (self.total_step as f32 / total_duration as f32).clamp(0.0, 1.0)
            },
        }
    }

    pub fn result(&self) -> Result<PresetResult, ValidationError> {
        let definition = self
            .definition
            .as_ref()
            .ok_or_else(|| ValidationError::Message("no experiment loaded".to_string()))?;
        let network = self
            .network
            .as_ref()
            .ok_or_else(|| ValidationError::Message("network missing".to_string()))?;
        Ok(match definition.result_config.kind {
            ResultKind::PatternRecognition => {
                PresetResult::PatternRecognition(self.pattern_recognition_result(definition))
            }
            ResultKind::MemoryEcho => PresetResult::MemoryEcho(self.memory_echo_result()),
            ResultKind::Generic => PresetResult::Generic {
                total_spikes: network.total_spikes,
                average_weight: network.average_weight(),
            },
        })
    }

    fn pattern_recognition_result(
        &self,
        definition: &ExperimentDefinition,
    ) -> PatternRecognitionResult {
        let a_phase = definition
            .phases
            .iter()
            .find(|phase| phase.id.contains("probe_a"))
            .map(|phase| phase.id.as_str())
            .unwrap_or("probe_a");
        let b_phase = definition
            .phases
            .iter()
            .find(|phase| phase.id.contains("probe_b"))
            .map(|phase| phase.id.as_str())
            .unwrap_or("probe_b");
        let mut a_selective = 0;
        let mut b_selective = 0;
        let mut mixed = 0;
        let mut silent = 0;
        let mut selectivity_sum = 0.0;
        for neuron_id in 0..definition.network.neuron_count as u32 {
            let a = phase_spikes(self.phase_frames.get(a_phase), neuron_id);
            let b = phase_spikes(self.phase_frames.get(b_phase), neuron_id);
            match (a, b) {
                (0, 0) => silent += 1,
                (a, b) if a > b => a_selective += 1,
                (a, b) if b > a => b_selective += 1,
                _ => mixed += 1,
            }
            let denom = (a + b).max(1) as f32;
            selectivity_sum += (a as f32 - b as f32).abs() / denom;
        }
        PatternRecognitionResult {
            a_selective_count: a_selective,
            b_selective_count: b_selective,
            mixed_count: mixed,
            silent_count: silent,
            average_selectivity_score: selectivity_sum / definition.network.neuron_count as f32,
            explanation_facts: vec![
                "trained with Pattern A before probe phases".to_string(),
                "selectivity compares probe A spikes against probe B spikes".to_string(),
            ],
        }
    }

    fn memory_echo_result(&self) -> MemoryEchoResult {
        let decay_curve = self.metrics.decay_curve();
        let echo_duration_steps = decay_curve
            .iter()
            .take_while(|value| **value > 0.01)
            .count() as u32;
        let remaining_active_neuron_count = self
            .metrics
            .snapshots
            .last()
            .map(|snapshot| {
                snapshot
                    .recent_firing_rates
                    .iter()
                    .filter(|rate| **rate > 0.01)
                    .count()
            })
            .unwrap_or(0) as u32;
        let total_spikes = self
            .metrics
            .frames
            .iter()
            .map(|frame| frame.statistics.batch_spikes)
            .sum::<u32>();
        let spontaneous_spike_rate = if self.metrics.frames.is_empty() {
            0.0
        } else {
            total_spikes as f32 / self.metrics.frames.len() as f32
        };
        MemoryEchoResult {
            echo_duration_steps,
            decay_curve,
            remaining_active_neuron_count,
            spontaneous_spike_rate,
            explanation_facts: vec![
                "silence phase measures activity after external input is removed".to_string(),
                "decay curve is based on mean recent firing rate".to_string(),
            ],
        }
    }
}

fn phase_spikes(frames: Option<&Vec<StepFrame>>, neuron_id: u32) -> u32 {
    frames
        .into_iter()
        .flat_map(|frames| frames.iter())
        .flat_map(|frame| frame.spikes.iter())
        .filter(|event| event.neuron_id == neuron_id)
        .count() as u32
}

pub fn pattern_recognition_preset(seed: u64) -> ExperimentDefinition {
    let network = SimulationConfig {
        seed: Some(seed),
        neuron_count: 24,
        connection_density: 0.2,
        ..SimulationConfig::default()
    };
    ExperimentDefinition {
        schema_version: SUPPORTED_SCHEMA_VERSION,
        preset_id: Some("pattern_recognition".to_string()),
        seed: Some(seed),
        patterns: vec![
            Pattern::new("a", "Pattern A", &[4, 5, 6, 7], 1.3),
            Pattern::new("b", "Pattern B", &[12, 13, 14, 15], 1.3),
        ],
        phases: vec![
            phase(
                "train_a",
                PhaseType::Train,
                16,
                true,
                constant("a", 0.0),
                seed + 1,
            ),
            phase(
                "probe_a",
                PhaseType::Probe,
                8,
                false,
                constant("a", 0.0),
                seed + 2,
            ),
            phase(
                "probe_b",
                PhaseType::Probe,
                8,
                false,
                constant("b", 0.0),
                seed + 3,
            ),
        ],
        metric_windows: vec![],
        result_config: ResultConfig {
            kind: ResultKind::PatternRecognition,
        },
        network,
    }
}

pub fn memory_echo_preset(seed: u64) -> ExperimentDefinition {
    let network = SimulationConfig {
        seed: Some(seed),
        neuron_count: 24,
        connection_density: 0.22,
        ..SimulationConfig::default()
    };
    ExperimentDefinition {
        schema_version: SUPPORTED_SCHEMA_VERSION,
        preset_id: Some("memory_echo".to_string()),
        seed: Some(seed),
        patterns: vec![Pattern {
            id: "a".to_string(),
            label: "Pattern A".to_string(),
            activations: (4..12)
                .map(|neuron_id| PatternActivation {
                    neuron_id,
                    current: 1.25,
                })
                .collect(),
        }],
        phases: vec![
            phase(
                "train_a",
                PhaseType::Train,
                18,
                true,
                constant("a", 0.0),
                seed + 11,
            ),
            phase(
                "silence",
                PhaseType::Silence,
                18,
                false,
                PatternSchedule::Silence,
                seed + 12,
            ),
        ],
        metric_windows: vec![],
        result_config: ResultConfig {
            kind: ResultKind::MemoryEcho,
        },
        network,
    }
}

fn constant(pattern_id: &str, noise_probability: f32) -> PatternSchedule {
    PatternSchedule::Constant {
        pattern_id: pattern_id.to_string(),
        noise_probability,
    }
}

fn phase(
    id: &str,
    phase_type: PhaseType,
    duration_steps: u32,
    learning_enabled: bool,
    schedule: PatternSchedule,
    phase_seed: u64,
) -> Phase {
    Phase {
        id: id.to_string(),
        phase_type,
        duration_steps,
        learning_enabled,
        schedule,
        phase_seed: Some(phase_seed),
        stop_condition: None,
    }
}

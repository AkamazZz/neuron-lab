# CCN Visualization Specification

## 1. Product Idea

CCN Visualization is an interactive neural simulation lab.

The app lets users watch a small brain-like network learn through spikes, timing, and changing connections. It is not an LLM, not a chatbot, and not a production AI model. It is a visual experiment tool for understanding how simple neural learning rules can create patterns, memory echoes, selectivity, and activity dynamics.

The product should support two levels of use:

1. Preset simulations that run automatically.
2. Custom simulations where the user can edit patterns, parameters, and experiment phases.

The first version should focus on clarity and visual feedback, not biological completeness.

## 2. Core Concept

The app simulates a network of neurons.

Each neuron can:

- receive input
- accumulate activity
- spike when activity crosses a threshold
- influence other neurons through synapses

Each synapse can:

- excite another neuron
- inhibit another neuron
- change its strength over time

Learning happens through spike timing:

```text
If neuron A fires shortly before neuron B,
connection A -> B becomes stronger.

If the timing is reversed or uncorrelated,
connection A -> B becomes weaker.
```

This rule is called STDP: Spike-Timing-Dependent Plasticity.

## 3. Product Positioning

The app should feel like:

```text
Interactive Neural Lab
```

Not:

```text
AI assistant
Machine learning dashboard
Scientific paper replica
Generic graph visualizer
```

The main promise:

```text
Design or select a neural experiment, run it, and understand visually what happened.
```

## 4. Difference From BrainSim

BrainSim is mainly:

```text
simulation engine first
visualization second
fixed demo experiments
```

CCN Visualization should be:

```text
experiment lab first
simulation engine underneath
preset and custom experiment flows
```

Main differences:

- more guided experiment flows
- custom pattern creation
- configurable train/test phases
- reusable experiment model
- clearer result metrics
- saved experiment configurations
- better explanation of outcomes
- scalable network topology, preferably sparse instead of fully connected

The core idea can remain similar:

- neurons
- synapses
- spikes
- STDP
- inhibition
- pattern input
- visual output

But the implementation should be structured around experiments, not around one hardcoded demo.

## 5. Main User Modes

### 5.1 Preset Experiments

Preset experiments are ready-made flows.

The user selects an experiment and clicks Run.

The app automatically:

1. creates the network
2. creates input patterns
3. runs training phases
4. runs probe/test phases
5. collects metrics
6. visualizes the result
7. explains what happened

Preset mode is for users who want to understand the concept without configuring everything manually.

### 5.2 Custom Lab

Custom Lab is for users who want control.

The user can configure:

- neuron count
- inhibitory percentage
- connection density
- learning rate
- noise level
- training steps
- probe steps
- input patterns
- sequence order
- random seed
- learning enabled/disabled per phase

The user should be able to create an experiment like:

```text
Train:
Pattern A -> Pattern B -> Pattern C

Test:
Show only Pattern A

Expected:
Network activates B, then C.
```

Or:

```text
Train:
Pattern A

Test:
Pattern A with 40% noise

Expected:
Network still reacts similarly to A.
```

## 6. Simulation Flow

The core runtime flow:

```text
User selects settings
        ↓
Simulator creates Network
        ↓
Network contains Neurons + Synapses
        ↓
Every simulation step:
    build input
    compute synaptic input from previous spikes
    update neurons
    collect current spikes
    update synapses if learning is enabled
    update metrics
    publish state to UI
        ↓
UI draws raster, charts, heatmaps, and results
```

## 7. Network Model

### 7.1 Neuron

A neuron stores:

- id
- type
- membrane/activity value
- recovery/adaptation value
- spike state
- recent firing rate
- homeostasis scale

Initial neuron types:

- excitatory regular neuron
- inhibitory fast neuron

Later neuron types can be added, but the MVP only needs these two.

### 7.2 Synapse

A synapse stores:

- source neuron id
- target neuron id
- weight
- inhibitory/excitatory behavior
- pre-spike trace
- post-spike trace
- learning parameters

Weights should be clamped:

```text
excitatory: 0.0 ... maxWeight
inhibitory: -maxWeight ... 0.0
```

### 7.3 Topology

MVP should support:

- sparse random connectivity
- configurable connection density
- no self-connections

Fully connected networks are simple, but they scale poorly because every step becomes close to O(N^2).

The Rust core should store topology as sparse adjacency data, not as a dense matrix.

Recommended internal representation:

```text
Network
  neurons: Vec<Neuron>
  outgoing_edges: Vec<Vec<SynapseEdge>>
  incoming_edges: Vec<Vec<EdgeId>>
```

Alternative later representation for performance:

```text
CSR / compressed sparse row
  offsets: Vec<u32>
  target_ids: Vec<u32>
  weights: Vec<f32>
  synapse_state: Vec<SynapseState>
```

The MVP can use adjacency lists because they are simpler to implement and debug. The public FFI API should not expose this internal representation directly.

## 8. Experiment Model

Experiments should be represented as data, not hardcoded screens.

Recommended structure:

```text
ExperimentDefinition
  id
  name
  description
  networkConfig
  inputPatterns
  phases
  metrics
  resultExplanation
```

Each phase:

```text
ExperimentPhase
  name
  type: warmup | train | probe | silence | custom
  durationSteps
  patternSchedule
  inputStrength
  learningEnabled
  noiseLevel
  phaseSeed
  metricWindows
  stopCondition
```

`patternSchedule` is required because some experiments need a sequence, not a single static pattern.

Examples:

```text
constant Pattern A
Pattern A -> Pattern B -> Pattern C
Pattern A with 40% noise
silence
custom generated input
```

`metricWindows` defines which steps are used for metrics. This prevents warmup or transition spikes from polluting final results.

`stopCondition` is optional for MVP, but the model should allow it:

```text
fixed duration
activity below threshold
activity above threshold
sequence completed
timeout
```

Example:

```text
Pattern Recognition

Setup:
80 neurons
20% inhibitory
30% connection density
Pattern A
Pattern B

Phase 1:
Train Pattern A for 500 steps
Learning enabled

Phase 2:
Probe Pattern A for 100 steps
Learning disabled

Phase 3:
Probe Pattern B for 100 steps
Learning disabled

Result:
Compare firing rates for A and B.
```

## 9. Preset Experiments

### 9.1 Pattern Recognition

Goal:

Check whether the network reacts differently to a trained pattern and an untrained pattern.

Flow:

```text
Train on Pattern A
Probe Pattern A
Probe Pattern B
Compare responses
```

Metrics:

- A-selective neurons
- B-selective neurons
- mixed neurons
- silent neurons
- average selectivity score

Selectivity formula:

```text
score = (firesA - firesB) / (firesA + firesB)
```

For MVP, `firesA` and `firesB` mean per-neuron spike rates normalized by probe duration:

```text
firesA = spikes from this neuron during Pattern A probe / Pattern A probe steps
firesB = spikes from this neuron during Pattern B probe / Pattern B probe steps
```

Only configured probe metric windows should be counted.

Meaning:

```text
score near +1 = prefers A
score near -1 = prefers B
score near 0 = no clear preference
```

### 9.2 Sequence Memory

Goal:

Check whether the network can learn a temporal sequence.

Flow:

```text
Train A -> B -> C repeatedly
Show only A
Check whether B and C activity follows
```

Metrics:

- sequence recall accuracy
- delay between expected and actual activation
- number of correctly recalled steps

### 9.3 Noise Recovery

Goal:

Check whether the network still recognizes a pattern when part of the input is corrupted.

Flow:

```text
Train clean Pattern A
Probe clean Pattern A
Probe noisy Pattern A
Compare responses
```

Metrics:

- similarity between clean and noisy response
- recognition confidence
- failure threshold by noise percentage

### 9.4 Memory Echo

Goal:

Check whether trained activity continues after input disappears.

Flow:

```text
Train Pattern A
Switch input to silence
Measure how long activity remains
```

Metrics:

- echo duration
- decay curve
- remaining active neurons
- spontaneous spike rate

### 9.5 Inhibition Balance

Goal:

Show how inhibitory neurons stabilize or suppress the network.

Flow:

```text
Run same input with different inhibitory percentages
Compare activity
```

Metrics:

- average spike rate
- burst count
- silent periods
- instability score

Expected behavior:

```text
too little inhibition -> chaotic firing
balanced inhibition -> stable activity
too much inhibition -> silence
```

## 10. UI Structure

Recommended first version:

```text
Sidebar
  Experiments
  Custom Lab
  Network Settings
  Run Controls

Main Area
  Live Simulation
  Results
  Pattern Editor
  Metrics
```

### 10.1 Live Simulation View

Should show:

- spike raster
- spike count over time
- neuron activity heatmap
- connection/weight heatmap
- current phase
- current step

Raster:

```text
x-axis = time
y-axis = neuron index
dot = spike
```

### 10.2 Experiment View

Should show:

- selected experiment
- phase timeline
- run/pause/reset controls
- progress
- live metrics
- final result summary

### 10.3 Pattern Editor

Should allow:

- selecting active neurons for a pattern
- changing input strength
- adding noise
- creating Pattern A/B/C/etc.
- previewing pattern shape

Simple MVP pattern editor:

```text
grid of neurons
click neuron to toggle input on/off
slider for strength
save as Pattern A/B/C
```

## 11. Result Explanation

Every experiment should produce a human-readable explanation.

Example:

```text
The network was trained on Pattern A for 500 steps.
After training, 34 neurons responded more strongly to Pattern A than Pattern B.
This suggests that spike timing strengthened pathways related to Pattern A.
```

The explanation should avoid overstating intelligence.

Avoid:

```text
The network understands the pattern.
The network thinks.
The network has real memory.
```

Prefer:

```text
The network developed stronger responses to this input.
The activity pattern persisted after input stopped.
The trained response was partially recovered from noisy input.
```

## 12. MVP Scope

MVP should include:

- native app shell
- Flutter app shell
- InheritedWidget/InheritedNotifier for dependency injection
- ChangeNotifier controllers for app state
- Rust simulation core
- Dart FFI wrapper
- Rust build integration through native_toolchain_rust
- simulation loop
- sparse network
- excitatory and inhibitory neurons
- STDP learning
- preset Pattern Recognition experiment
- preset Memory Echo experiment
- spike raster visualization
- spike count chart
- basic pattern editor
- final metrics summary
- ability to reset and rerun with same seed

MVP should not include:

- LLM features
- real biological accuracy claims
- cloud sync
- account system
- large-scale neural simulation
- Metal acceleration
- flutter_rust_bridge
- Flutter Hooks
- external state managers such as Riverpod, Bloc, or Provider
- complex 3D visualization

## 13. Future Scope

Possible later additions:

- sequence prediction experiment
- noise recovery experiment
- inhibition balance experiment
- save/load experiment configs
- export spike trains to CSV
- export metrics to JSON
- compare multiple runs
- Metal compute backend
- iPad companion viewer
- lesson/tutorial mode

## 14. Suggested Implementation Direction

The implementation direction is:

```text
Flutter + InheritedNotifier + ChangeNotifier
Dart FFI + native_toolchain_rust
Rust simulation core
CustomPainter visualizations
```

The app should not use `flutter_rust_bridge` for the MVP. The preferred integration is `native_toolchain_rust`, because it uses Dart build hooks to build and bundle the Rust code with the Flutter package.

The Flutter side owns:

```text
screens
controls
pattern editor
animation/ticker lifecycle
state controllers
visual rendering
result panels
```

The Rust side owns:

```text
neurons
synapses
network state
STDP learning
experiment runner
metrics
deterministic random seed
```

The most important architectural decision is to separate:

```text
Rust Simulation Core
FFI Boundary
Flutter State/DI
Flutter Visualization/UI
```

Do not put experiment logic directly inside views. Views should call controller methods, controllers should call the Dart FFI wrapper, and Rust should own the simulation truth.

### 14.1 Flutter State And DI

The Flutter app should use:

```text
InheritedNotifier / InheritedWidget
ChangeNotifier
CustomPainter
```

No Flutter Hooks and no external state manager are required for the MVP.

Responsibilities:

```text
InheritedNotifier
  provides SimulationController and rebuild subscriptions

ChangeNotifier
  stores current app state and calls notifyListeners()

StatefulWidget / State
  manages animation controllers, timers, text controllers, scroll controllers, and disposal

CustomPainter
  draws raster, spike charts, heatmaps, and weight views
```

Recommended Flutter modules:

```text
lib/
  main.dart
  app.dart

  core/
    ffi/
      ccn_native.dart
      ccn_bindings.dart
      ccn_repository.dart
    scope/
      simulation_scope.dart

  features/
    simulation/
      simulation_controller.dart
      simulation_state.dart
      simulation_screen.dart
      painters/
        raster_painter.dart
        spike_histogram_painter.dart
        activity_heatmap_painter.dart
        weight_matrix_painter.dart

    experiments/
      experiment_picker.dart
      experiment_runner_panel.dart
      experiment_result_panel.dart

    pattern_editor/
      pattern_editor_screen.dart
      pattern_editor_controller.dart
```

### 14.2 Rust Core

Recommended Rust modules:

```text
rust/
  Cargo.toml
  rust-toolchain.toml
  src/
    lib.rs
    ffi.rs
    core/
      neuron.rs
      synapse.rs
      network.rs
      topology.rs
      config.rs
    simulation/
      simulator.rs
      frame.rs
      handles.rs
    experiments/
      definition.rs
      phase.rs
      runner.rs
      presets.rs
      result.rs
    patterns/
      input_pattern.rs
      pattern_library.rs
    metrics/
      selectivity.rs
      spike_stats.rs
      weight_stats.rs
```

### 14.3 Native Toolchain Setup

The Flutter package should include a build hook:

```text
hook/build.dart
```

The build hook should use:

```text
native_toolchain_rust
hooks
```

Rust should live in:

```text
rust/
```

The Rust crate should build as:

```text
staticlib
cdylib
```

The Rust toolchain should be pinned in:

```text
rust/rust-toolchain.toml
```

The channel should use a concrete version, not plain `stable`, so builds are reproducible.

### 14.4 FFI Boundary

Use a handle-based C ABI.

Flutter should not receive or mutate full Rust structs directly.

The FFI boundary must be explicit about:

- status/error handling
- pointer ownership
- buffer lifetime
- frame lifetime
- ABI version
- integer and float sizes
- snapshot encoding
- thread assumptions

All public FFI functions must be panic-safe. Rust panics must be caught at the boundary and converted into an error status.

### 14.4.1 Handles And Ownership

`SimulationHandle` should be opaque to Dart.

Recommended representation:

```text
SimulationHandle = pointer-sized opaque handle
```

Rules:

- handles are created only by Rust
- handles are freed only through `ccn_free_simulation`
- after free, a handle is invalid
- double-free is a caller bug, but Rust should guard where practical
- null handles must return an invalid-handle status
- Dart must not construct, copy, or mutate Rust-owned memory directly

For MVP, simulation handles should be used from one Dart isolate/thread at a time. Multi-threaded access can be added later behind explicit locking.

### 14.4.2 Status And Errors

Do not return only data from fallible calls.

Use status-returning APIs:

```text
CcnStatus
  code: i32
  error_kind: i32
  message: BufferHandle optional
```

Recommended status codes:

```text
0  ok
1  invalid_handle
2  invalid_argument
3  invalid_state
4  validation_failed
5  allocation_failed
6  internal_error
7  experiment_complete
```

The Dart wrapper should convert non-ok statuses into typed Dart exceptions or controller error states.

Recommended public Rust functions:

```text
ccn_create_simulation(config_json_ptr, config_json_len, out_handle) -> CcnStatus
ccn_free_simulation(handle) -> CcnStatus

ccn_validate_config(config_json_ptr, config_json_len, out_report_buffer) -> CcnStatus
ccn_validate_experiment(experiment_json_ptr, experiment_json_len, out_report_buffer) -> CcnStatus

ccn_reset_simulation(handle, reset_mode) -> CcnStatus
ccn_step_simulation(handle, steps, out_frame) -> CcnStatus

ccn_load_experiment(handle, experiment_json_ptr, experiment_json_len) -> CcnStatus
ccn_clear_experiment(handle) -> CcnStatus
ccn_step_experiment(handle, steps, out_frame) -> CcnStatus
ccn_get_experiment_state(handle, out_state) -> CcnStatus
ccn_get_phase_progress(handle, out_progress) -> CcnStatus
ccn_get_experiment_result(handle, out_buffer) -> CcnStatus

ccn_get_weight_snapshot(handle, out_buffer) -> CcnStatus
ccn_get_activity_snapshot(handle, out_buffer) -> CcnStatus

ccn_free_step_frame(frame) -> CcnStatus
ccn_free_buffer(buffer) -> CcnStatus
```

Hot-path data should be compact and fixed-size where possible.

### 14.4.3 Step Frame Layout

`StepFrame` is hot-path data. It is returned frequently and should not contain the whole raster history.

Rust should return only new spike events for the requested step batch. Flutter keeps its own rolling raster buffer.

Recommended layout:

```text
StepFrame
  abi_version: u32
  step_start: u64
  steps_advanced: u32
  spike_count: u32
  average_weight: f32
  current_phase_index: i32
  flags: u32
  spike_events_len: u32
  spike_events_ptr: *const SpikeEvent
```

Recommended spike event layout:

```text
SpikeEvent
  step_offset: u32
  neuron_id: u32
  membrane: f32
```

Ownership:

- Rust allocates `StepFrame` payload memory.
- Dart reads it during the current tick.
- Dart must call `ccn_free_step_frame(frame)` after copying needed data.
- `spike_events_ptr` is valid only until the frame is freed.
- If `spike_events_len == 0`, `spike_events_ptr` may be null.

The API should not return `StepFrame` by value if the generated Dart FFI binding makes pointer ownership clearer. A pointer/out-parameter is preferred.

### 14.4.4 Experiment Lifecycle

Experiments have explicit state:

```text
idle
loaded
running
paused
completed
failed
```

Rules:

- raw `ccn_step_simulation` advances the network without experiment phase logic
- `ccn_step_experiment` advances the active experiment and its phases
- when an experiment is loaded, the UI should normally call `ccn_step_experiment`
- raw stepping during a loaded experiment should either be rejected or explicitly documented as manual mode
- `ccn_reset_simulation` should define whether it resets only network state or network plus experiment state
- `ccn_clear_experiment` removes the active experiment and returns to normal simulation mode

Recommended reset modes:

```text
network_only
network_and_experiment
full_recreate_from_seed
```

`ccn_get_phase_progress` should expose:

```text
phase_index
phase_step
phase_duration_steps
total_step
total_duration_steps
progress_0_to_1
```

### 14.4.5 Snapshots

Heavy data should be requested occasionally:

```text
weight matrix
full activity snapshot
experiment result
debug state
```

Weight snapshots should not default to dense JSON. Sparse networks should expose sparse snapshot data.

Recommended weight snapshot encoding:

```text
WeightSnapshot
  abi_version: u32
  encoding: edge_list
  edge_count: u32
  source_ids: u32[]
  target_ids: u32[]
  weights: f32[]
```

Activity snapshots must define semantics explicitly.

Recommended MVP activity values:

```text
ActivitySnapshot
  neuron_count: u32
  membrane_values: f32[]
  recent_firing_rates: f32[]
  last_spike_flags: u8[]
```

Configs and large result summaries can use JSON for the MVP. Hot-path frames and large numeric snapshots should use typed binary buffers.

### 14.4.6 Config Versioning And Reproducibility

Every JSON config should include:

```text
schemaVersion
presetId optional
seed
networkConfig
patterns
phases
metrics
```

Validation must catch:

- unsupported schema version
- missing seed
- invalid neuron count
- invalid inhibitory fraction
- invalid connection density
- invalid pattern neuron ids
- invalid phase duration
- invalid noise level
- missing metric windows

Reproducibility guarantee for MVP:

```text
same app version
same Rust core version
same schema version
same config
same experiment definition
same seed
= same spike events and metrics
```

If Rust core changes break reproducibility, the app should expose the Rust core version in exported results.

### 14.4.7 ABI Rules

All FFI structs should define:

```text
abi_version
fixed-width integer types: u8/u32/u64/i32
float type: f32 for hot-path metrics
alignment assumptions
little-endian assumption for binary buffers
explicit free function for every Rust-owned allocation
```

The Dart FFI wrapper must be the only place where raw pointers are touched. Feature code should call a repository/controller API, not FFI functions directly.

## 15. Success Criteria

The first version is successful if a user can:

1. open the app
2. run a preset experiment
3. watch neurons spike in real time
4. see connections/activity change
5. understand the result from metrics and explanation
6. edit or create a simple custom pattern
7. rerun the experiment and compare behavior

The product should be understandable in the first minute without requiring the user to know neuroscience.

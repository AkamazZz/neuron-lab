# Simulation Feature Ownership

- `controller/`: presentation-facing state holder plus narrow orchestration entrypoints.
- `domain/`: pure Flutter business logic for run lifecycle, interaction, projection, selection, summaries, and render-data preparation.
- `ui/`: widgets, layout, controls, and inspector presentation.
- `painters/`: rendering only; painters consume render-ready inputs and do not derive business meaning.

Data access stays behind `lib/core/ffi/`. Widgets and painters should depend on typed domain or model APIs only.

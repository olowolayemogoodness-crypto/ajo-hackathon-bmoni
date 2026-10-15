# Project agent memory

This file is the project's committed home for project-intrinsic agent knowledge: build, test, release, architecture, and sharp-edge notes that should travel with the code.

- Add durable project-specific notes here as they are discovered through real work.

## UI conventions

- Use semantic roles from `lib/core/theme/app_theme.dart`; use `Theme.of(context).textTheme` for copy and `context.type` for money/code so amounts retain tabular figures.
- Keep status treatments accessible with a rounded Material icon plus a text label; `lib/core/widgets/status_chip.dart` enforces this for compact statuses.

## Validation

- Run `flutter analyze --no-pub` and `flutter test --no-pub`. The widget suite includes a 390×844 layout sweep of the primary savings flows.

## Maintaining this file

Keep this file for knowledge useful to almost every future agent session in this project.
Do not repeat what the codebase already shows; point to the authoritative file or command instead.
Prefer rewriting or pruning existing entries over appending new ones.
When updating this file, preserve this bar for all agents and keep entries concise.

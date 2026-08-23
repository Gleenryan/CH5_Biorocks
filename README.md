# Coralyst

Coralyst is a macOS SwiftUI application for monitoring reef sites, their
hydrophones, acoustic-health snapshots, and blast-detection alerts.

## Open the project

Open `Coralyst.xcodeproj` in Xcode, select the `CH5_Biorocks` scheme, and run
the macOS target. The project uses a file-system-synchronised Xcode group, so
Swift files placed under `CH5_Biorocks/` are included automatically.

## Source layout

```text
CH5_Biorocks/
├── App/                 App entry point, shell, sidebar, and routing
├── Core/                Domain models and the shared design system
├── Data/                Persistence-facing stores
├── Features/            User-facing workflows grouped by feature
├── Services/            Audio input, networking, and detection pipeline
├── Shared/              Reusable feature-level UI, such as alert cards
└── Resources/           Bundled classifier resources
```

### Ownership rules

- Put generic visual primitives in `Core/DesignSystem`.
- Put UI reused by multiple features, but still specific to Coralyst, in
  `Shared`.
- Keep complete screens and their feature-only components in `Features`.
- Keep audio capture, networking, and detection logic in `Services`.
- Keep SwiftData models in `Core/Domain/Models`; do not duplicate them in
  feature folders.

## Runtime behavior

- SwiftData persists Sites, Hydrophones, health snapshots, and alert events.
- Debug builds bootstrap the simulator and start the local hydrophone ingress
  server. Release builds do not start that debug-only server from the app shell.
- The app's microphone selection UI uses the macOS audio-input permission.

## Documentation

- [Privacy policy](PRIVACY.md)
- [Support](SUPPORT.md)


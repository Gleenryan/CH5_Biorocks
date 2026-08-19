# Coralyst Privacy Policy

**Effective date:** August 19, 2026

Coralyst is a macOS application for monitoring coral reef sites and analyzing hydrophone data. This policy explains how Coralyst handles information.

## Summary

Coralyst does not require an account and does not send personal information, microphone recordings, analytics, or advertising data to servers operated by the developer.

## Information handled by the app

Coralyst may process and store the following information locally on your Mac:

- Reef site names and geographic coordinates you enter.
- Hydrophone names, geographic coordinates, and the name and system identifier of a selected audio input device.
- Detection events, confidence scores, coral health measurements, generated summaries, and related timestamps.
- Temporary diagnostic status, waveform envelopes, and simulator information while the app is running.

This information supports the app's mapping, hydrophone management, detection, and coral health features.

## Microphone and audio data

Coralyst requests microphone access only when you choose to test or use an audio input. The microphone test checks whether the selected device is delivering audio frames.

Microphone and hydrophone audio is processed on the device. Coralyst does not record raw microphone audio to disk or upload raw audio to a developer-operated server. Audio received from the optional local simulator is accepted only through a local-only network connection and is processed in memory.

You can revoke microphone access at any time in **System Settings > Privacy & Security > Microphone**.

## Local storage and retention

Coralyst uses Apple's SwiftData framework to store sites, hydrophones, detection events, and coral health records in the app's local container on your Mac. The developer does not have access to this local database.

Local information remains on the device until you delete it through available app controls, reset the app's data, or remove the app's data container. For help removing local data, use the [Coralyst Support page](https://github.com/Gleenryan/CH5_Biorocks/blob/main/SUPPORT.md).

## Maps and Apple services

Coralyst uses Apple MapKit to display maps and coordinates. Requests needed to provide Apple map content are handled by Apple under [Apple's Privacy Policy](https://www.apple.com/legal/privacy/). Coralyst does not receive personal information from Apple about your use of MapKit.

When available, Coralyst may use Apple's system-provided on-device language model to create summaries. The app does not send those prompts or summaries to a developer-operated server.

## Analytics, advertising, and sharing

Coralyst does not include a developer-operated analytics service, advertising SDK, tracking SDK, or account system. The developer does not sell or share app data with data brokers or advertisers.

## Security

Coralyst runs in the macOS App Sandbox and uses system permission controls for microphone access. No method of storage or processing is completely risk-free, so keep macOS updated and protect access to your Mac.

## Children's privacy

Coralyst is not designed to collect personal information from children. Because the app does not operate an account or developer-controlled data collection service, the developer does not knowingly collect children's personal information through the app.

## Changes to this policy

This policy may be updated when Coralyst's features or data practices change. Updates will be published on this page with a revised effective date.

## Contact

For privacy questions or support, visit [Coralyst Support](https://github.com/Gleenryan/CH5_Biorocks/blob/main/SUPPORT.md). GitHub issues are public, so do not include microphone recordings, precise private locations, device identifiers, or other sensitive information.

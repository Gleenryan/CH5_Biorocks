"""Standalone exhibition visualizer for Coralyst demos.

Opens its own window (spectrograms + waveforms). Streams the same PCM into
the macOS app over the existing hydrophone protocol — processes stay separate,
results appear together.
"""

from reef_pipeline.exhibit.run import exhibit_cli

__all__ = ["exhibit_cli"]

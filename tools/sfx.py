#!/usr/bin/env python3
# Two synthesised placeholder sounds (Block B, knight-takes-pawn-clash): a swing
# whoosh and an impact crunch, written deterministically with no external audio
# assets. These are placeholders for a later AI-tool regeneration -- the file
# names and mount points (assets/sfx/swing.wav, assets/sfx/impact.wav) are the
# contract and stay stable across that swap.
#
# Deterministic: a fixed RNG seed means re-running this script byte-identically
# reproduces both files.
import os
import wave

import numpy as np

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "sfx")
SR = 44100
SEED = 20260817


def _write(path, samples):
	clipped = np.clip(samples, -1.0, 1.0)
	pcm = (clipped * 32767.0).astype("<i2")
	with wave.open(path, "w") as f:
		f.setnchannels(1)
		f.setsampwidth(2)
		f.setframerate(SR)
		f.writeframes(pcm.tobytes())


def _envelope(n, attack, decay):
	t = np.arange(n) / SR
	env = np.ones(n)
	a_n = max(1, int(attack * SR))
	env[:a_n] = np.linspace(0.0, 1.0, a_n)
	env *= np.exp(-t / decay)
	return env


def swing(duration=0.22):
	# Filtered noise under an envelope: white noise softened by a one-pole
	# lowpass into a "whoosh", fast attack, quick decay.
	rng = np.random.default_rng(SEED)
	n = int(duration * SR)
	noise = rng.uniform(-1.0, 1.0, n)
	filtered = np.empty(n)
	prev = 0.0
	alpha = 0.06  # low -> soft whoosh, not hiss
	for i in range(n):
		prev = prev + alpha * (noise[i] - prev)
		filtered[i] = prev
	env = _envelope(n, attack=0.015, decay=0.09)
	return filtered * env * 0.8


def impact(duration=0.25):
	# Low sine (the "crunch" body) plus a short broadband click transient (the
	# "contact" snap), summed -- deliberately not the same texture as the swing
	# so the two cues stay distinguishable start to finish.
	rng = np.random.default_rng(SEED + 1)
	n = int(duration * SR)
	t = np.arange(n) / SR
	body = np.sin(2 * np.pi * 90.0 * t) * np.exp(-t / 0.07)
	click_n = int(0.006 * SR)
	click = np.zeros(n)
	click[:click_n] = rng.uniform(-1.0, 1.0, click_n) * np.linspace(1.0, 0.0, click_n)
	return np.clip(body * 0.9 + click * 0.6, -1.0, 1.0)


if __name__ == "__main__":
	os.makedirs(OUT, exist_ok=True)
	for name, fn in (("swing.wav", swing), ("impact.wav", impact)):
		path = os.path.join(OUT, name)
		_write(path, fn())
		print("wrote %s" % path)

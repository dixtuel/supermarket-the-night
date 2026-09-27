# Original audio

All WAV files in this folder were synthesized for Supermarket: The Night by `generate_audio.py` on 26 September 2026. No third-party samples or melodies are used.

- `night_shift_theme.wav` — soft 82 BPM eight-bar loop for the night shift.
- `ui_confirm.wav` — menu and button confirmation.
- `xp_collect.wav` — two-note stock-token pickup cue.
- `level_up.wav` — short ascending level-up cue.
- `player_hurt.wav` — compact low impact cue when the clerk takes damage.
- `boss_arrival.wav` — three-part Return Cart entrance cue.
- `shift_survived.wav` — short major-key shift-clear cue.
- `shift_lost.wav` — descending defeat cue.

Regenerate all source audio with:

```bash
python3 assets/audio/generate_audio.py
```

The WAV files are original synthesized audio assets dedicated under CC0 1.0; see [`ASSET_LICENSE.md`](../../ASSET_LICENSE.md). The generator script is source code and remains under the repository MIT license.

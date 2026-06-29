# Global signal bus. Director emits; views/UI listen. Keep signals here, not logic.
extends Node

## Emitted when a beat (dialogue line / wait) begins. text is "" for non-spoken beats.
signal beat_started(index: int, text: String)

## Emitted once the episode's last beat completes.
signal episode_finished

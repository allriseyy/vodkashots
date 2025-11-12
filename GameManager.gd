extends Node

var score: int = 0

func add_score(points: int = 1):
	score += points
	emit_signal("score_changed", score)

signal score_changed(new_score)

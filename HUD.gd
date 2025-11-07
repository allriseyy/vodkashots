extends CanvasLayer

@onready var score_label = $ScoreLabel

func _ready():
	score_label.text = "Score: 0"
	GameManager.connect("score_changed", Callable(self, "_on_score_changed"))

func _on_score_changed(new_score):
	score_label.text = "Score: " + str(new_score)

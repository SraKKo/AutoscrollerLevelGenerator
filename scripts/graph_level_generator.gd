class_name AbstractGraphLevelGenerator
extends Node

@export_range(7, 30, 1) var level_size := 12
@export_range(0.0, 1.0, 0.01) var branch_chance := 0.68
@export_range(1, 2, 1) var max_consecutive_straights := 2

var topology_generator := SharedLevelTopologyGenerator.new()

func generate(seed_value: int) -> Dictionary:
	return topology_generator.generate(
		seed_value,
		level_size,
		branch_chance,
		max_consecutive_straights
	)

extends Node


func get_ai_config() -> Dictionary:
	return {
		"category_weights": {
			"attack": 0.6,
			"defence": 0.2,
			"skill": 0.2
		},

		"opening_patterns": [
			[
				"normal_attack",
				"dodge",
				"multi_attack"
			],
			[
				"guard",
				"normal_attack",
				"heavy_attack"
			]
		],

		"actions": {
			"normal_attack": {
				"id": "normal_attack",
				"name": "普通攻击",
				"category": "attack",
				"weight": 0.5,
				"time_cost": 20,
				"execute_priority": 1,
				"effect_type": "damage",
				"target_type": "player",
				"damage": 10
			},

			"multi_attack": {
				"id": "multi_attack",
				"name": "连续攻击",
				"category": "attack",
				"weight": 0.3,
				"time_cost": 28,
				"execute_priority": 1,
				"effect_type": "multi_damage",
				"target_type": "player",
				"hit_count": 3,
				"damage_per_hit": 4
			},

			"heavy_attack": {
				"id": "heavy_attack",
				"name": "重击",
				"category": "attack",
				"weight": 0.2,
				"time_cost": 48,
				"execute_priority": 1,
				"effect_type": "damage",
				"target_type": "player",
				"damage": 25
			},

			"dodge": {
				"id": "dodge",
				"name": "闪避",
				"category": "defence",
				"weight": 0.55,
				"time_cost": 16,
				"execute_priority": 2,
				"effect_type": "dodge_buff",
				"target_type": "self",
				"dodge_bonus": 0.35,
				"duration": 20,
				"cannot_repeat": true
			},

			"guard": {
				"id": "guard",
				"name": "防御",
				"category": "defence",
				"weight": 0.45,
				"time_cost": 16,
				"execute_priority": 2,
				"effect_type": "block_next_attack",
				"target_type": "self",
				"charges": 1,
				"duration": 25,
				"cannot_repeat": true
			},

			"rebirth": {
				"id": "rebirth",
				"name": "重生",
				"description":"使用三次后被击杀会立即重生",
				"category": "skill",
				"weight": 1.0,
				"time_cost": 36,
				"execute_priority": 1,
				"effect_type": "rebirth_charge",
				"target_type": "self",
				"charge_amount": 1,
				"cannot_repeat": true
			}
		}
	}

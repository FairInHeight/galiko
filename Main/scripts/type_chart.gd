extends Node
class_name TypeManager

enum Type { DEFAULT, FIRE, ICE, TOXIC, ELECTRIC, PLASMA, NUCLEAR, CYBER, PSYCHIC, VOID, BIO }

# Constant damage multipliers
const WEAKNESS_MULTIPLIER: float = 2.0
const RESISTANCE_MULTIPLIER: float = 0.5
const NEUTRAL_MULTIPLIER: float = 1.0

# The master data table mapping each type to its defensive traits
const TYPE_DATA = {
	Type.DEFAULT:  { "weak": [], "res": [] },
	Type.FIRE:     { "weak": [Type.ICE, Type.PLASMA], "res": [Type.FIRE, Type.TOXIC] },
	Type.ICE:      { "weak": [Type.FIRE, Type.PLASMA], "res": [Type.ICE, Type.ELECTRIC] },
	Type.TOXIC:    { "weak": [Type.FIRE, Type.NUCLEAR], "res": [Type.TOXIC, Type.ELECTRIC] },
	Type.ELECTRIC: { "weak": [Type.TOXIC, Type.NUCLEAR], "res": [Type.ELECTRIC, Type.ICE] },
	Type.PLASMA:   { "weak": [Type.BIO, Type.ELECTRIC], "res": [Type.PLASMA, Type.FIRE] },
	Type.NUCLEAR:  { "weak": [Type.ICE, Type.ELECTRIC], "res": [Type.NUCLEAR, Type.TOXIC] },
	Type.CYBER:    { "weak": [Type.TOXIC, Type.ELECTRIC], "res": [Type.PLASMA, Type.NUCLEAR] },
	Type.PSYCHIC:  { "weak": [Type.VOID, Type.CYBER], "res": [Type.PSYCHIC, Type.BIO] },
	Type.VOID:     { "weak": [Type.PLASMA], "res": [Type.VOID] },
	Type.BIO:      { "weak": [Type.TOXIC, Type.PSYCHIC], "res": [Type.PLASMA, Type.CYBER] }
}

## 🟢 STATIC RECONCILIATION ENGINE: Universally callable without a live tree instance
static func get_damage_multiplier(attack_type: Type, defender_typing: Variant) -> float:
	# 1. Multi-Type Array Check
	if defender_typing is Array or defender_typing is Array[Type]:
		var composite_multiplier := 1.0
		for single_type in defender_typing:
			composite_multiplier *= _calculate_single_multiplier(attack_type, single_type)
		return composite_multiplier
		
	# 2. Single-Type Fallback
	return _calculate_single_multiplier(attack_type, defender_typing)


## 🟢 STATIC HELPER: Computes the mathematical intersection of types
static func _calculate_single_multiplier(attack_type: Type, defender_type: Type) -> float:
	var traits = TYPE_DATA.get(defender_type, TYPE_DATA[Type.DEFAULT])
	
	if attack_type in traits["weak"]:
		return WEAKNESS_MULTIPLIER
	elif attack_type in traits["res"]:
		return RESISTANCE_MULTIPLIER
		
	return NEUTRAL_MULTIPLIER

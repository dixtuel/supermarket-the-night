class_name CharacterRoster
extends RefCounted
## Single source of truth for playable characters. Add selectable characters here.

const NIGHT_CLERK: CharacterDefinition = preload("res://data/characters/night_clerk.tres")
const DNZ: CharacterDefinition = preload("res://data/characters/dnz.tres")
const CHARACTERS: Array[CharacterDefinition] = [NIGHT_CLERK, DNZ]
const DEFAULT_CHARACTER_ID: StringName = &"night_clerk"


static func get_character(character_id: StringName) -> CharacterDefinition:
	for character: CharacterDefinition in CHARACTERS:
		if character.id == character_id:
			return character
	return NIGHT_CLERK


static func get_character_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for character: CharacterDefinition in CHARACTERS:
		ids.append(character.id)
	return ids


static func get_index(character_id: StringName) -> int:
	for index in range(CHARACTERS.size()):
		if CHARACTERS[index].id == character_id:
			return index
	return 0

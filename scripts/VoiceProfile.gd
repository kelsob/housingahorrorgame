class_name VoiceProfile
extends Resource

## Reusable voice-generator preset for VoiceAudioStreamPlayer.
## Base values define the calm AI voice; emotion groups can override on top.

@export_group("Source")
## Alphabet bank folder under res://addons/godot-voice-generator/sound/alphabet/.
@export_enum("high", "med", "low", "lowest") var alphabet_pitch: String = "med"
@export var source_type: VoiceAudioStreamPlayer.SOURCE_TYPE = VoiceAudioStreamPlayer.SOURCE_TYPE.ALPHABET

@export_group("Pitch")
@export_range(0.1, 10.0, 0.01) var main_pitch_scale: float = 1.0
@export_range(1.0, 4.0, 0.01) var question_pitch_scale: float = 1.4
@export_range(0.0, 3.0, 0.01) var random_pitch: float = 1.0
@export_range(0.0, 24.0, 0.1) var random_volume_offset_db: float = 0.0

@export_group("Timing")
@export_range(0.0, 2.0, 0.01) var word_pause: float = 0.1
@export_range(0.0, 2.0, 0.01) var punctuation_pause: float = 0.2
## Letters per chunk for GENERATOR source only. Alphabet source always uses 1 letter per blip.
@export_range(0, 10, 1) var syllable_size: int = 3
## How much of each word to discard (0-1). Higher = fewer letters kept = fewer blips per word.
## Alphabet: each kept letter is one voice blip / mouth frame.
@export_range(0.0, 1.0, 0.01) var word_cutting_percentage: float = 0.0

@export_group("Angry Mods")
## Absolute values while angry.
@export_enum("keep", "high", "med", "low", "lowest") var angry_alphabet_pitch: String = "med"
@export_range(0.1, 10.0, 0.01) var angry_main_pitch_scale: float = 5.55
@export_range(0.0, 3.0, 0.01) var angry_random_pitch: float = 1.5
@export_range(1.0, 4.0, 0.01) var angry_question_pitch_scale: float = 2.73
@export_range(0.0, 2.0, 0.01) var angry_punctuation_pause: float = 1.0
@export_range(0.0, 1.0, 0.01) var angry_word_cutting_percentage: float = 0.7
@export_range(-2.0, 2.0, 0.1) var angry_random_volume_offset_db_add: float = 0.8
@export_range(0.7, 1.3, 0.01) var angry_word_pause_mul: float = 0.9

@export_group("Agitated Mods")
## Absolute pitch values while agitated.
@export_enum("keep", "high", "med", "low", "lowest") var agitated_alphabet_pitch: String = "med"
@export_range(0.1, 10.0, 0.01) var agitated_main_pitch_scale: float = 5.15
@export_range(0.0, 3.0, 0.01) var agitated_random_pitch: float = 1.25
@export_range(1.0, 4.0, 0.01) var agitated_question_pitch_scale: float = 2.3
@export_range(-2.0, 2.0, 0.1) var agitated_random_volume_offset_db_add: float = 0.3
@export_range(0.7, 1.3, 0.01) var agitated_word_pause_mul: float = 0.95
@export_range(0.7, 1.3, 0.01) var agitated_punctuation_pause_mul: float = 0.96
@export_range(-0.15, 0.15, 0.01) var agitated_word_cutting_add: float = -0.01


func apply_to(player: VoiceAudioStreamPlayer, emotion: StringName = &"") -> void:
	var pitch_bank: String = alphabet_pitch
	var main_pitch: float = main_pitch_scale
	var question_pitch: float = question_pitch_scale
	var rand_pitch: float = random_pitch
	var rand_vol: float = random_volume_offset_db
	var pause_word: float = word_pause
	var pause_punct: float = punctuation_pause
	var cutting: float = word_cutting_percentage

	match emotion:
		&"angry":
			if angry_alphabet_pitch != "keep":
				pitch_bank = angry_alphabet_pitch
			main_pitch = angry_main_pitch_scale
			question_pitch = angry_question_pitch_scale
			rand_pitch = angry_random_pitch
			pause_punct = angry_punctuation_pause
			cutting = angry_word_cutting_percentage
			rand_vol = maxf(0.0, rand_vol + angry_random_volume_offset_db_add)
			pause_word = maxf(0.0, pause_word * angry_word_pause_mul)
		&"agitated":
			if agitated_alphabet_pitch != "keep":
				pitch_bank = agitated_alphabet_pitch
			main_pitch = agitated_main_pitch_scale
			question_pitch = agitated_question_pitch_scale
			rand_pitch = agitated_random_pitch
			rand_vol = maxf(0.0, rand_vol + agitated_random_volume_offset_db_add)
			pause_word = maxf(0.0, pause_word * agitated_word_pause_mul)
			pause_punct = maxf(0.0, pause_punct * agitated_punctuation_pause_mul)
			cutting = clampf(cutting + agitated_word_cutting_add, 0.0, 1.0)

	player.source_type = source_type
	player.main_pitch_scale = main_pitch
	player.question_pitch_scale = question_pitch
	player.random_pitch = rand_pitch
	player.random_volume_offset_db = rand_vol
	player.word_pause = pause_word
	player.punctuation_pause = pause_punct
	player.syllable_size = syllable_size
	player.word_cutting_percentage = cutting
	if source_type == VoiceAudioStreamPlayer.SOURCE_TYPE.ALPHABET:
		player.alphabet_mapping = build_alphabet_mapping(pitch_bank)


func build_alphabet_mapping(pitch_override: String = "") -> Dictionary:
	var pitch: String = pitch_override.strip_edges()
	if pitch.is_empty():
		pitch = alphabet_pitch.strip_edges()
	if pitch.is_empty():
		pitch = "med"
	var base: String = "res://addons/godot-voice-generator/sound/alphabet/%s/" % pitch
	return {
		"default": load(base + "a.wav") as AudioStream,
		"a": load(base + "a.wav") as AudioStream,
		"b": load(base + "b.wav") as AudioStream,
		"c": load(base + "c.wav") as AudioStream,
		"d": load(base + "d.wav") as AudioStream,
		"e": load(base + "e.wav") as AudioStream,
		"f": load(base + "f.wav") as AudioStream,
		"g": load(base + "g.wav") as AudioStream,
		"h": load(base + "h.wav") as AudioStream,
		"i": load(base + "i.wav") as AudioStream,
		"j": load(base + "j.wav") as AudioStream,
		"k": load(base + "k.wav") as AudioStream,
		"l": load(base + "l.wav") as AudioStream,
		"m": load(base + "m.wav") as AudioStream,
		"n": load(base + "n.wav") as AudioStream,
		"o": load(base + "o.wav") as AudioStream,
		"p": load(base + "p.wav") as AudioStream,
		"q": load(base + "q.wav") as AudioStream,
		"r": load(base + "r.wav") as AudioStream,
		"s": load(base + "s.wav") as AudioStream,
		"t": load(base + "t.wav") as AudioStream,
		"u": load(base + "u.wav") as AudioStream,
		"v": load(base + "v.wav") as AudioStream,
		"w": load(base + "w.wav") as AudioStream,
		"x": load(base + "x.wav") as AudioStream,
		"y": load(base + "y.wav") as AudioStream,
		"z": load(base + "z.wav") as AudioStream,
	}


## Dictionary form for systems that still take profile dicts (door / intercom).
func to_dictionary() -> Dictionary:
	return {
		"enabled": true,
		"alphabet_pitch": alphabet_pitch,
		"main_pitch_scale": main_pitch_scale,
		"question_pitch_scale": question_pitch_scale,
		"random_pitch": random_pitch,
		"random_volume_offset_db": random_volume_offset_db,
		"word_pause": word_pause,
		"punctuation_pause": punctuation_pause,
		"syllable_size": syllable_size,
		"word_cutting_percentage": word_cutting_percentage,
	}

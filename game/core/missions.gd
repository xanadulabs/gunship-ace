extends RefCounted
## The campaign. Pure data. Positions are (x, z) in meters, map center is (0, 0).
##
## Objective types:
##   destroy  every unit with the tag is destroyed, by any means
##   flip     count units with the tag are flipped by the rotor wash
##   rescue   count downed crew are landed at the LZ
##   stop     at most "allow" units with the tag reach the end of their road
##   return   land at the LZ once everything else is done (always last)


static func count() -> int:
	return all().size()


static func get_mission(index: int) -> Dictionary:
	var list := all()
	return list[clampi(index, 0, list.size() - 1)]


static func all() -> Array:
	return [_dust_off(), _convoy(), _crew(), _ace()]


static func _p(x: float, z: float) -> Vector2:
	return Vector2(x, z)


static func _dust_off() -> Dictionary:
	return {
		"name": "Dust Off",
		"code": "MISSION 1",
		"brief": [
			"A militia column has set up at the crossroads. Their radar spots our",
			"transports, and their jeeps run the road at night.",
			"",
			"The Hind's rotor wash is your best weapon down low. Come down to the",
			"ground, hold still beside a jeep, and the downwash flips it.",
			"",
			"Fuel is short. Grab the red drums on the way. Green crates reload, white crates repair.",
		],
		"half": 110.0,
		"seed": 11,
		"lz": _p(0, 92),
		"lz_yaw": 0.0,
		"trees": 70,
		"bushes": 110,
		"roads": [
			{"pts": [_p(0, 104), _p(0, 40), _p(6, -10), _p(4, -60), _p(-10, -104)], "w": 5.0},
			{"pts": [_p(-104, -14), _p(-40, -10), _p(6, -10), _p(60, -18), _p(104, -24)], "w": 5.0},
			{"pts": [_p(60, -18), _p(64, -58)], "w": 3.5},
		],
		"pads": [
			{"at": _p(0, 92), "r": _p(8, 8)},
			{"at": _p(64, -62), "r": _p(14, 11)},
			{"at": _p(-14, 4), "r": _p(16, 12)},
		],
		"buildings": [
			{"at": _p(-20, 6), "v": 0}, {"at": _p(-8, 14), "v": 2, "drop": "armor"},
			{"at": _p(16, 2), "v": 1}, {"at": _p(-30, -24), "v": 2}, {"at": _p(18, -28), "v": 0, "drop": "fuel"},
		],
		"flags": [_p(-12, -2), _p(58, -54), _p(4, 84)],
		"units": [
			{"kind": "jeep", "at": _p(-80, -13), "tag": "patrol", "path": [_p(-80, -13), _p(-20, -10)]},
			{"kind": "jeep", "at": _p(40, -15), "tag": "patrol", "path": [_p(40, -15), _p(95, -23)]},
			{"kind": "jeep", "at": _p(5, -30), "tag": "patrol", "path": [_p(5, -30), _p(2, -80)]},
			{"kind": "radar", "at": _p(66, -66), "tag": "radar"},
			{"kind": "aaa", "at": _p(54, -60), "tag": "aa"},
			{"kind": "aaa", "at": _p(76, -56), "tag": "aa"},
			{"kind": "technical", "at": _p(-14, -6), "tag": "", "yaw": 90.0},
			{"kind": "soldier", "at": _p(-4, 2)}, {"kind": "soldier", "at": _p(-24, -4)},
			{"kind": "soldier", "at": _p(10, -6)}, {"kind": "soldier", "at": _p(60, -50)},
			{"kind": "soldier", "at": _p(70, -72)}, {"kind": "soldier", "at": _p(26, -22)},
		],
		"pickups": [
			{"kind": "fuel", "at": _p(-40, 40)}, {"kind": "fuel", "at": _p(70, 20)},
			{"kind": "ammo", "at": _p(30, 30)}, {"kind": "armor", "at": _p(-60, -50)},
		],
		"crew": [],
		"objectives": [
			{"type": "flip", "tag": "patrol", "count": 3, "label": "Flip 3 patrol jeeps with the rotor wash"},
			{"type": "destroy", "tag": "aa", "label": "Destroy the 2 AA guns at the radar site"},
			{"type": "destroy", "tag": "radar", "label": "Destroy the radar station"},
			{"type": "return", "label": "Return to the LZ"},
		],
	}


static func _convoy() -> Dictionary:
	var road := [_p(-128, -40), _p(-80, -44), _p(-50, -20), _p(-40, 20), _p(0, 34), _p(40, 20), _p(70, 40), _p(98, 62)]
	return {
		"name": "Convoy",
		"code": "MISSION 2",
		"brief": [
			"A supply convoy is crossing the flats toward the fuel depot in the east.",
			"Four trucks, two technical escorts.",
			"",
			"Stop the trucks before they reach the depot. The wash only shakes a",
			"truck, so use the gun and rockets. The escort technicals will flip.",
			"",
			"Then burn the depot. It is covered by AA guns and a ZSU-23,",
			"which can reach you at any height.",
		],
		"half": 130.0,
		"seed": 23,
		"lz": _p(-20, 112),
		"lz_yaw": 0.0,
		"trees": 80,
		"bushes": 120,
		"roads": [
			{"pts": road, "w": 5.5},
			{"pts": [_p(-20, 124), _p(-20, 70), _p(-40, 20)], "w": 3.5},
			{"pts": [_p(0, 34), _p(10, -60), _p(-30, -124)], "w": 3.5},
		],
		"pads": [
			{"at": _p(-20, 112), "r": _p(8, 8)},
			{"at": _p(104, 70), "r": _p(20, 16)},
		],
		"buildings": [
			{"at": _p(-6, 46), "v": 2}, {"at": _p(12, 44), "v": 0, "drop": "ammo"},
			{"at": _p(86, 84), "v": 1}, {"at": _p(-62, -4), "v": 2, "drop": "fuel"},
		],
		"flags": [_p(96, 52), _p(-22, 104)],
		"units": [
			{"kind": "technical", "at": road[0], "tag": "escort", "path": road, "loop": false, "delay": 4.0, "speed": 4.2},
			{"kind": "truck", "at": road[0], "tag": "convoy", "path": road, "loop": false, "delay": 7.5},
			{"kind": "truck", "at": road[0], "tag": "convoy", "path": road, "loop": false, "delay": 11.0},
			{"kind": "truck", "at": road[0], "tag": "convoy", "path": road, "loop": false, "delay": 14.5},
			{"kind": "truck", "at": road[0], "tag": "convoy", "path": road, "loop": false, "delay": 18.0},
			{"kind": "technical", "at": road[0], "tag": "escort", "path": road, "loop": false, "delay": 21.5, "speed": 4.2},
			{"kind": "depot", "at": _p(108, 72), "tag": "depot"},
			{"kind": "depot", "at": _p(100, 86), "tag": "depot"},
			{"kind": "aaa", "at": _p(90, 66), "tag": ""},
			{"kind": "aaa", "at": _p(118, 88), "tag": ""},
			{"kind": "zsu", "at": _p(112, 54), "tag": "", "path": [_p(112, 54), _p(84, 94)]},
			{"kind": "soldier", "at": _p(96, 76)}, {"kind": "soldier", "at": _p(104, 60)},
			{"kind": "soldier", "at": _p(4, 40)}, {"kind": "soldier", "at": _p(-48, 14)},
			{"kind": "jeep", "at": _p(10, -40), "path": [_p(10, -40), _p(-20, -110)]},
		],
		"pickups": [
			{"kind": "fuel", "at": _p(-60, 60)}, {"kind": "fuel", "at": _p(40, -30)},
			{"kind": "ammo", "at": _p(-90, 10)}, {"kind": "armor", "at": _p(50, 90)},
			{"kind": "ammo", "at": _p(70, -10)},
		],
		"crew": [],
		"objectives": [
			{"type": "stop", "tag": "convoy", "allow": 1, "label": "Stop the supply trucks (1 may get through)"},
			{"type": "destroy", "tag": "depot", "label": "Destroy the fuel depot"},
			{"type": "return", "label": "Return to the LZ"},
		],
	}


static func _crew() -> Dictionary:
	return {
		"name": "Downed Crew",
		"code": "MISSION 3",
		"brief": [
			"A transport went down in the hills last night. Five crew are alive and",
			"scattered across enemy ground.",
			"",
			"Two SAM sites cover the area. A SAM cannot lock on at ground height,",
			"so stay down until they are gone.",
			"",
			"To pick up crew, hold still on the ground over them. Bring them back to",
			"the LZ and hold still on the pad. The Hind carries six.",
		],
		"half": 140.0,
		"seed": 37,
		"lz": _p(-110, 110),
		"lz_yaw": -45.0,
		"trees": 110,
		"bushes": 130,
		"roads": [
			{"pts": [_p(-140, 100), _p(-60, 60), _p(0, 0), _p(60, -40), _p(140, -50)], "w": 5.0},
			{"pts": [_p(0, 0), _p(-20, -60), _p(-60, -140)], "w": 4.0},
			{"pts": [_p(0, 0), _p(50, 50), _p(90, 120)], "w": 4.0},
		],
		"pads": [
			{"at": _p(-110, 110), "r": _p(8, 8)},
			{"at": _p(70, -80), "r": _p(16, 14)},
			{"at": _p(-70, -40), "r": _p(14, 12)},
			{"at": _p(10, 6), "r": _p(16, 14)},
		],
		"buildings": [
			{"at": _p(20, 14), "v": 0}, {"at": _p(-2, 20), "v": 2, "drop": "fuel"},
			{"at": _p(26, -6), "v": 1, "drop": "armor"}, {"at": _p(60, -94), "v": 2},
		],
		"flags": [_p(8, -4), _p(66, -70)],
		"units": [
			{"kind": "sam", "at": _p(70, -80), "tag": "sam"},
			{"kind": "sam", "at": _p(-70, -40), "tag": "sam"},
			{"kind": "aaa", "at": _p(80, -66), "tag": ""},
			{"kind": "aaa", "at": _p(-58, -52), "tag": ""},
			{"kind": "tank", "at": _p(16, -2), "tag": "", "path": [_p(16, -2), _p(50, -36)]},
			{"kind": "tank", "at": _p(-30, 30), "tag": ""},
			{"kind": "technical", "at": _p(-60, 60), "path": [_p(-60, 60), _p(-4, 4)]},
			{"kind": "jeep", "at": _p(40, 40), "path": [_p(40, 40), _p(80, 106)]},
			{"kind": "jeep", "at": _p(-24, -70), "path": [_p(-24, -70), _p(-56, -130)]},
			{"kind": "soldier", "at": _p(36, 66)}, {"kind": "soldier", "at": _p(44, 70)},
			{"kind": "soldier", "at": _p(-84, -24)}, {"kind": "soldier", "at": _p(90, -30)},
			{"kind": "soldier", "at": _p(4, -14)}, {"kind": "soldier", "at": _p(-10, 8)},
			{"kind": "soldier", "at": _p(100, -90)},
		],
		"pickups": [
			{"kind": "fuel", "at": _p(-80, 80)}, {"kind": "fuel", "at": _p(30, -100)},
			{"kind": "fuel", "at": _p(100, 60)}, {"kind": "ammo", "at": _p(-100, -80)},
			{"kind": "armor", "at": _p(-20, 100)}, {"kind": "ammo", "at": _p(110, -20)},
		],
		"crew": [_p(40, 76), _p(96, -36), _p(-90, -20), _p(6, -20), _p(110, -110)],
		"objectives": [
			{"type": "destroy", "tag": "sam", "label": "Destroy the 2 SAM sites"},
			{"type": "rescue", "count": 5, "label": "Bring the 5 crew to the LZ"},
			{"type": "return", "label": "Return to the LZ"},
		],
	}


static func _ace() -> Dictionary:
	return {
		"name": "Gunship Ace",
		"code": "MISSION 4",
		"brief": [
			"The militia command post is in a walled compound at the north end of the",
			"valley. Tanks and two ZSU-23s guard it, and a SAM covers it from above.",
			"",
			"The chin gun barely scratches armor. Use rockets and missiles on the",
			"tanks and ZSUs, and keep your missiles for the bunker.",
			"",
			"Two of our crew are held near the compound. Bring them home.",
		],
		"half": 150.0,
		"seed": 53,
		"lz": _p(0, 132),
		"lz_yaw": 0.0,
		"trees": 120,
		"bushes": 140,
		"roads": [
			{"pts": [_p(0, 150), _p(0, 60), _p(-30, 0), _p(-10, -60), _p(0, -110), _p(0, -150)], "w": 5.5},
			{"pts": [_p(-150, -20), _p(-30, 0), _p(40, 10), _p(150, -10)], "w": 4.5},
			{"pts": [_p(0, -110), _p(60, -120)], "w": 3.5},
		],
		"pads": [
			{"at": _p(0, 132), "r": _p(8, 8)},
			{"at": _p(0, -112), "r": _p(26, 18)},
			{"at": _p(-34, 4), "r": _p(16, 12)},
		],
		"buildings": [
			{"at": _p(-22, -100), "v": 1}, {"at": _p(22, -100), "v": 0, "drop": "ammo"},
			{"at": _p(-18, -126), "v": 2}, {"at": _p(-44, 12), "v": 0, "drop": "fuel"},
			{"at": _p(-26, 18), "v": 2, "drop": "armor"}, {"at": _p(44, 22), "v": 1},
		],
		"flags": [_p(8, -104), _p(-8, -104), _p(-36, -6)],
		"units": [
			{"kind": "bunker", "at": _p(0, -118), "tag": "hq"},
			{"kind": "zsu", "at": _p(-30, -80), "tag": "zsu", "path": [_p(-30, -80), _p(30, -84)]},
			{"kind": "zsu", "at": _p(40, -20), "tag": "zsu", "path": [_p(40, -20), _p(70, 0)]},
			{"kind": "tank", "at": _p(-10, -80), "tag": "armor"},
			{"kind": "tank", "at": _p(16, -86), "tag": "armor", "yaw": 30.0},
			{"kind": "tank", "at": _p(-28, 0), "tag": "armor", "path": [_p(-28, 0), _p(-6, 50)]},
			{"kind": "sam", "at": _p(30, -130), "tag": ""},
			{"kind": "aaa", "at": _p(-36, -110), "tag": ""},
			{"kind": "aaa", "at": _p(36, -104), "tag": ""},
			{"kind": "aaa", "at": _p(-60, -6), "tag": ""},
			{"kind": "technical", "at": _p(-140, -18), "path": [_p(-140, -18), _p(-40, 0)]},
			{"kind": "technical", "at": _p(140, -10), "path": [_p(140, -10), _p(44, 10)]},
			{"kind": "jeep", "at": _p(0, 40), "path": [_p(0, 40), _p(-28, 2)]},
			{"kind": "radar", "at": _p(-90, -90), "tag": ""},
			{"kind": "soldier", "at": _p(-8, -96)}, {"kind": "soldier", "at": _p(10, -96)},
			{"kind": "soldier", "at": _p(-14, -132)}, {"kind": "soldier", "at": _p(14, -132)},
			{"kind": "soldier", "at": _p(-40, 20)}, {"kind": "soldier", "at": _p(50, 0)},
			{"kind": "soldier", "at": _p(-84, -84)},
		],
		"pickups": [
			{"kind": "fuel", "at": _p(-70, 80)}, {"kind": "fuel", "at": _p(70, 70)},
			{"kind": "fuel", "at": _p(90, -60)}, {"kind": "ammo", "at": _p(-90, 40)},
			{"kind": "ammo", "at": _p(100, 30)}, {"kind": "armor", "at": _p(-100, -40)},
			{"kind": "armor", "at": _p(60, 110)},
		],
		"crew": [_p(-46, -120), _p(50, -116)],
		"objectives": [
			{"type": "destroy", "tag": "zsu", "label": "Destroy the 2 ZSU-23s"},
			{"type": "destroy", "tag": "armor", "label": "Destroy the 3 tanks"},
			{"type": "destroy", "tag": "hq", "label": "Destroy the command bunker"},
			{"type": "rescue", "count": 2, "label": "Bring the 2 prisoners to the LZ"},
			{"type": "return", "label": "Return to the LZ"},
		],
	}

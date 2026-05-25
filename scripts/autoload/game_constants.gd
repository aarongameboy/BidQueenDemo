extends Node
## Global tuning for BidKing demo.

## 与 project.godot display/window/size 一致，全屏背景按此视口铺满
const VIEWPORT_WIDTH: int = 1280
const VIEWPORT_HEIGHT: int = 720

const MAX_ROUNDS: int = 5
const PLAYER_COUNT: int = 4

const OVERBID_COMPENSATION_RATE: float = 0.1
const STARTING_SILVER: int = 2_000_000
## 房间练习局内携带银币（不影响大厅资产）
const PRACTICE_MATCH_SILVER: int = 2_000_000
const ROOM_MIN_PLAYERS: int = 2
const ROOM_MAX_PLAYERS: int = 4
const ROOM_DEFAULT_PORT: int = 17777
const UNBOX_ITEM_DELAY: float = 0.35
const ROUND_PAUSE_SECONDS: float = 0.4
const INTEL_CARD_DELAY: float = 0.45
const INTEL_ITEM_REVEAL_DELAY: float = 0.35
const INTEL_TEASER_DELAY: float = 1.2
const CINEMATIC_AUCTION_START_HOLD: float = 2.2
const CINEMATIC_HERITAGE_HOLD: float = 3.8
const CINEMATIC_ROUND_START_HOLD: float = 3.5
const CINEMATIC_ROUND_REVEAL_HOLD: float = 3.8
const CINEMATIC_AUCTION_SUCCESS_HOLD: float = 3.2
const CINEMATIC_AUCTION_FAIL_HOLD: float = 3.2

## Open auction defaults (overridden by match_config.json)
const DEFAULT_BID_WINDOW_SECONDS: float = 25.0
const DEFAULT_MIN_RAISE: int = 50_000
const DEFAULT_STARTING_BID: int = 10_000
const DEFAULT_BOT_TICK_SECONDS: float = 1.2

enum MatchPhase {
	LOBBY,
	INFO,
	OPEN_BOARD,
	BID_WINDOW,
	BID_RESOLVE,
	UNBOX,
	SETTLEMENT,
	MATCH_END,
}

enum Quality {
	WHITE,
	GREEN,
	BLUE,
	PURPLE,
	GOLD,
	RED,
}

const QUALITY_SLOT_VALUE: Dictionary = {
	Quality.WHITE: 500,
	Quality.GREEN: 2000,
	Quality.BLUE: 8000,
	Quality.PURPLE: 20_000,
	Quality.GOLD: 80_000,
	Quality.RED: 400_000,
}

const QUALITY_COUNT: int = 6

const QUALITY_NAMES: PackedStringArray = [
	"白", "绿", "蓝", "紫", "金", "红",
]

## 品质色规范（与 items_master quality_color 一致）
const QUALITY_COLOR_HEX: Dictionary = {
	"white": "#B2B2B2",
	"green": "#44612b",
	"blue": "#29487d",
	"purple": "#4e297d",
	"gold": "#b1a221",
	"red": "#a4492a",
}

## 品质文字色（高亮，适合深色背景上的富文本）
const QUALITY_TEXT_COLOR_HEX: Dictionary = {
	"white": "#E0E0E0",
	"green": "#7CCD5F",
	"blue": "#5EB3FF",
	"purple": "#C882FF",
	"gold": "#FFD645",
	"red": "#FF6B5E",
}

const QUALITY_KEYS: PackedStringArray = [
	"white", "green", "blue", "purple", "gold", "red",
]


static func get_quality_color_hex(quality_name: String) -> String:
	return str(QUALITY_COLOR_HEX.get(quality_name.strip_edges().to_lower(), "#B2B2B2"))


static func get_quality_text_color_hex(quality_enum: int) -> String:
	var idx: int = clampi(quality_enum, 0, QUALITY_KEYS.size() - 1)
	return str(QUALITY_TEXT_COLOR_HEX.get(QUALITY_KEYS[idx], "#E0E0E0"))


static func get_quality_color(quality_enum: int) -> Color:
	var idx: int = clampi(quality_enum, 0, QUALITY_KEYS.size() - 1)
	return Color.from_string(get_quality_color_hex(QUALITY_KEYS[idx]), Color.GRAY)


const MATCH_CONFIG_PATH := "res://config/match_config.json"

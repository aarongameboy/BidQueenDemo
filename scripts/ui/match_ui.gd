extends Control

const MatchControllerScript = preload("res://scripts/match/match_controller.gd")
const PlayerSeatCardScript = preload("res://scripts/ui/player_seat_card.gd")
const WarehouseGridPanelScript = preload("res://scripts/ui/warehouse_grid_panel.gd")
const SettlementRecycleBarScript = preload("res://scripts/ui/settlement_recycle_bar.gd")
const ItemEncyclopediaScript = preload("res://scripts/ui/item_encyclopedia.gd")
const FontUtilScript = preload("res://scripts/ui/font_util.gd")
const UiTextureCacheScript = preload("res://scripts/ui/ui_texture_cache.gd")
const SettlementOverlayScript = preload("res://scripts/ui/settlement_overlay.gd")
const MatchCinematicOverlayScript = preload("res://scripts/ui/match_cinematic_overlay.gd")
const MatchIntelScript = preload("res://scripts/match/match_intel.gd")
const ToastOverlayScript = preload("res://scripts/ui/toast_overlay.gd")
const BidNumpadScript = preload("res://scripts/ui/bid_numpad.gd")
const EmotePanelScript = preload("res://scripts/ui/emote_panel.gd")
const EmoteBubbleScript = preload("res://scripts/ui/emote_bubble.gd")
const MapSelectionUIScript = preload("res://scripts/ui/map_selection_ui.gd")
const LobbyUIScript = preload("res://scripts/ui/lobby_ui.gd")
const MatchmakingOverlayScript = preload("res://scripts/ui/matchmaking_overlay.gd")
const MapModeConfigScript = preload("res://scripts/data/map_mode_config.gd")
const CollectionUIScript = preload("res://scripts/ui/collection_ui.gd")
const CharacterSelectionUIScript = preload("res://scripts/ui/character_selection_ui.gd")
const LeaderboardUIScript = preload("res://scripts/ui/leaderboard_ui.gd")
const WarehouseUIScript = preload("res://scripts/ui/warehouse_ui.gd")
const ShopUIScript = preload("res://scripts/ui/shop_ui.gd")
const RoomBattleUIScript = preload("res://scripts/ui/room_battle_ui.gd")
const ItemCatalogScript = preload("res://scripts/data/item_catalog.gd")
const UiButtonStyleScript = preload("res://scripts/ui/ui_button_style.gd")
const UiCloseButtonScript = preload("res://scripts/ui/ui_close_button.gd")
const UiMoneyIconScript = preload("res://scripts/ui/ui_money_icon.gd")

const BID_TIMER_PREFIX: String = "本轮拍卖倒计时："
const BID_TIMER_BASE_FONT_SIZE: int = 32
const BID_TIMER_URGENT_FONT_BONUS: int = 4
const BID_TIMER_URGENT_SECONDS: float = 5.0
const BID_TIMER_NORMAL_COLOR: Color = Color(0.92, 0.94, 1.0, 1.0)
const BID_TIMER_URGENT_COLOR: Color = Color(1.0, 0.32, 0.32, 1.0)

@onready var _bg_texture: TextureRect = %BgTexture
@onready var _top_silver: Label = %TopSilverLabel
@onready var _top_gold: Label = %TopGoldLabel
@onready var _gold_row: HBoxContainer = $RootMargin/RootVBox/TopBar/GoldRow
@onready var _emote_btn: Button = %EmoteButton
@onready var _players_list: VBoxContainer = %PlayersList
@onready var _round_banner: Label = %RoundBannerLabel
@onready var _instant_kill_banner: Label = %InstantKillMultLabel
@onready var _skill_list: VBoxContainer = %SkillEffectsList
@onready var _min_bid_label: Label = %MinBidLabel
@onready var _bid_timer: Label = %BidTimerLabel
@onready var _bid_input: LineEdit = %BidAmountInput
@onready var _bid_status: Label = %BidStatusLabel
@onready var _raise_btn: Button = %RaiseButton
@onready var _pass_btn: Button = %PassRoundButton
@onready var _forfeit_btn: Button = %ForfeitButton
@onready var _item_btn: Button = %ItemToolButton
@onready var _loot_host: Control = %LootPanelHost
@onready var _restart_btn: Button = %RestartButton
@onready var _log: RichTextLabel = %LogText
@onready var _root_margin: MarginContainer = $RootMargin

var _controller = null
var _seat_cards: Array[PlayerSeatCard] = []
var _loot_panel: WarehouseGridPanel = null
var _settlement_recycle_bar: SettlementRecycleBar = null
var _encyclopedia: ItemEncyclopedia = null
var _human_locked_this_round: bool = false
var _forfeited: bool = false
var _settlement_overlay: SettlementOverlay = null
var _cinematic_overlay: MatchCinematicOverlay = null
var _main_columns: Control = null
var _bid_area: Control = null
var _toast: ToastOverlay = null
var _bid_numpad: BidNumpad = null
var _bid_popup: PanelContainer = null
var _bid_popup_close_btn: Button = null
var _bid_popup_timer: Label = null
var _bid_buttons_host: Control = null
var _bid_overlay: Control = null
var _left_panel: PanelContainer = null
var _center_panel: PanelContainer = null
var _right_panel: PanelContainer = null
var _bid_buttons_row: HBoxContainer = null
var _settlement_layout_spacer: Control = null
var _loot_canvas_layer: CanvasLayer = null
var _restart_canvas_layer: CanvasLayer = null
var _restart_btn_host: Control = null
var _settlement_canvas_layer: CanvasLayer = null
var _right_panel_style_normal: StyleBoxFlat = null
var _right_panel_reparented: bool = false
var _emote_panel: EmotePanel = null
var _emote_bubble: EmoteBubble = null
var _map_selection: MapSelectionUI = null
var _lobby: LobbyUI = null
var _matchmaking: MatchmakingOverlay = null
var _collection_ui: CollectionUI = null
var _character_ui: Control = null
var _leaderboard_ui: Control = null
var _warehouse_ui: WarehouseUI = null
var _shop_ui: ShopUI = null
var _last_settlement_result = null
var _settlement_claimed: bool = false
var _pending_map_id: String = ""
var _pending_mode_id: String = ""
var _room_flow_active: bool = false
var _practice_match_active: bool = false
var _ai_practice_flow_active: bool = false
var _room_battle_ui: RoomBattleUI = null
var _layout_hidden_for_cinematic: bool = false
enum RestartBtnPlacement { HIDDEN, BID_ROW, SETTLEMENT_BOTTOM }
var _restart_placement: int = RestartBtnPlacement.HIDDEN
var _menu_catalog = null
var _controller_signals_bound: bool = false


func _ready() -> void:
    _setup_background()
    _style_transparent_panels()
    _controller = get_node_or_null("../MatchController")
    if _controller:
        _bind_controller(_controller)
    call_deferred("_finish_ready_deferred")


func _finish_ready_deferred() -> void:
    FontUtilScript.apply_cjk_font(self, 14)
    _loot_panel = WarehouseGridPanelScript.new()
    _loot_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _loot_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _loot_host.add_child(_loot_panel)
    _setup_settlement_recycle_bar()
    _raise_btn.pressed.connect(_on_open_bid_popup_pressed)
    _pass_btn.pressed.connect(_on_pass_pressed)
    _forfeit_btn.pressed.connect(_on_forfeit_pressed)
    _item_btn.pressed.connect(_on_item_tool_pressed)
    _restart_btn.pressed.connect(_on_restart_pressed)
    if _controller == null:
        _controller = get_node_or_null("../MatchController")
    if _controller:
        _bind_controller(_controller)
        _setup_encyclopedia()
    _set_bid_controls_enabled(false)
    _log.visible = false
    if _min_bid_label:
        _min_bid_label.visible = false
    _bid_input.placeholder_text = "输入出价金额"
    _bid_input.text_submitted.connect(_on_bid_input_submitted)
    _main_columns = $RootMargin/RootVBox/MainColumns
    _left_panel = _main_columns.get_node("LeftPanel") as PanelContainer
    _center_panel = _main_columns.get_node("CenterPanel") as PanelContainer
    _right_panel = _main_columns.get_node("RightPanel") as PanelContainer
    _bid_area = $RootMargin/RootVBox/MainColumns/CenterPanel/CenterMargin/CenterVBox/BidArea
    _bid_buttons_row = _bid_area.get_node("BidButtons") as HBoxContainer
    _configure_column_layout()
    _configure_skill_scroll()
    _setup_settlement_layout_spacer()
    _setup_loot_canvas_layer()
    _setup_bid_action_row()
    _setup_bid_popup()
    _apply_money_icons()
    _setup_emote_panel()
    _setup_emote_bubble()
    _style_bid_action_buttons()
    _setup_map_selection()
    _setup_lobby()
    _setup_matchmaking()
    _setup_room_battle()
    _setup_collection()
    _setup_characters()
    _setup_leaderboard()
    _setup_warehouse()
    _setup_shop()
    _setup_restart_button_anchor()
    _show_lobby()
    _hide_currency_display()
    resized.connect(_on_match_ui_resized)
    _settlement_overlay = SettlementOverlayScript.new()
    _settlement_overlay.bind_main_columns(_main_columns)
    _setup_settlement_canvas_layer()
    _settlement_overlay.claim_pressed.connect(_on_settlement_claim)
    _cinematic_overlay = MatchCinematicOverlayScript.new()
    add_child(_cinematic_overlay)
    _toast = ToastOverlayScript.new()
    add_child(_toast)
    _reset_bid_timer_style()


func _hide_currency_display() -> void:
    if _gold_row:
        _gold_row.visible = false


func _apply_money_icons() -> void:
    if _gold_row == null:
        return
    for child in _gold_row.get_children():
        if child is ColorRect:
            UiMoneyIconScript.replace_color_rect(child as ColorRect)


func _setup_emote_panel() -> void:
    if _emote_btn == null:
        return
    _emote_panel = EmotePanelScript.new()
    add_child(_emote_panel)
    FontUtilScript.apply_cjk_font(_emote_panel, 14)
    _emote_btn.pressed.connect(_on_emote_button_pressed)
    _emote_panel.emote_picked.connect(_on_emote_picked)
    _emote_btn.text = "表情"
    _emote_btn.custom_minimum_size = Vector2(0, 44)
    _emote_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _emote_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    _emote_btn.visible = false
    UiButtonStyleScript.apply(_emote_btn, Color(0.9, 0.92, 0.98), 14)


func _on_emote_button_pressed() -> void:
    if _emote_panel and _emote_btn:
        _emote_panel.toggle_near(_emote_btn)


func _setup_map_selection() -> void:
    _map_selection = MapSelectionUIScript.new()
    _map_selection.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(_map_selection)
    move_child(_map_selection, -1)
    _map_selection.match_confirmed.connect(_on_map_match_confirmed)
    _map_selection.selection_cancelled.connect(_on_map_selection_cancelled)
    _map_selection.hide()


func _setup_lobby() -> void:
    _lobby = LobbyUIScript.new()
    _lobby.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(_lobby)
    move_child(_lobby, -1)
    _lobby.quick_match_pressed.connect(_on_lobby_quick_match)
    _lobby.room_battle_pressed.connect(_on_lobby_room_battle)
    _lobby.ai_practice_pressed.connect(_on_lobby_ai_practice)
    _lobby.coming_soon_pressed.connect(_on_coming_soon)
    _lobby.encyclopedia_pressed.connect(_on_open_encyclopedia)
    _lobby.collection_pressed.connect(_on_open_collection)
    _lobby.characters_pressed.connect(_on_open_characters)
    _lobby.leaderboard_pressed.connect(_on_open_leaderboard)
    _lobby.warehouse_pressed.connect(_on_open_warehouse)
    _lobby.shop_pressed.connect(_on_open_shop)
    _lobby.hide()


func _setup_collection() -> void:
    _collection_ui = CollectionUIScript.new()
    _collection_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(_collection_ui)
    move_child(_collection_ui, -1)
    _collection_ui.closed.connect(_on_collection_closed)
    _collection_ui.hide()


func _setup_characters() -> void:
    _character_ui = CharacterSelectionUIScript.new()
    _character_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(_character_ui)
    move_child(_character_ui, -1)
    _character_ui.closed.connect(_on_characters_closed)
    _character_ui.character_selected.connect(_on_character_selected)
    _character_ui.hide()


func _setup_matchmaking() -> void:
    _matchmaking = MatchmakingOverlayScript.new()
    add_child(_matchmaking)
    move_child(_matchmaking, -1)
    _matchmaking.matching_finished.connect(_on_matchmaking_finished)
    _matchmaking.matching_cancelled.connect(_on_matchmaking_cancelled)
    _matchmaking.hide()


func _setup_room_battle() -> void:
    _room_battle_ui = RoomBattleUIScript.new()
    _room_battle_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(_room_battle_ui)
    move_child(_room_battle_ui, -1)
    _room_battle_ui.hub_back_pressed.connect(_on_room_hub_back)
    _room_battle_ui.room_left.connect(_on_room_left)
    _room_battle_ui.hide()
    var net: Node = get_node_or_null("/root/RoomNetwork")
    if net:
        net.match_start_requested.connect(_on_room_match_start_requested)
        net.lobby_error.connect(_on_room_network_error)


func _get_persisted_silver() -> int:
    var portfolio: Node = get_node_or_null("/root/PlayerPortfolio")
    if portfolio:
        return maxi(0, int(portfolio.total_assets))
    if _controller:
        return _controller.get_human_silver_preview()
    return GameConstants.STARTING_SILVER


func _persist_portfolio_from_match() -> void:
    var portfolio: Node = get_node_or_null("/root/PlayerPortfolio")
    if portfolio == null or _controller == null:
        return
    portfolio.sync_total(_controller.get_human_silver_preview())


func _play_lobby_bgm() -> void:
    var bgm: Node = get_node_or_null("/root/BgmPlayer")
    if bgm:
        bgm.play_lobby()


func _play_map_bgm(map_id: String) -> void:
    var bgm: Node = get_node_or_null("/root/BgmPlayer")
    if bgm:
        bgm.play_for_map(map_id)


func _is_match_in_progress() -> bool:
    return _controller != null and _controller.is_match_running()


func _show_lobby() -> void:
    if _is_match_in_progress():
        return
    const MenuBackgroundScript = preload("res://scripts/ui/menu_background.gd")
    MenuBackgroundScript.set_viewport_dim(0.34)
    _ai_practice_flow_active = false
    _hide_map_selection()
    if _matchmaking:
        _matchmaking.hide()
    _play_lobby_bgm()
    if _lobby:
        _lobby.refresh_portfolio()
        _lobby.show()
        _lobby.z_index = 120
        _lobby.move_to_front()
    _hide_match_layout()
    _exit_settlement_ui()


func _hide_lobby() -> void:
    if _lobby:
        _lobby.hide()


func _on_lobby_quick_match() -> void:
    _room_flow_active = false
    _ai_practice_flow_active = false
    _hide_lobby()
    _show_map_selection(false)


func _on_lobby_room_battle() -> void:
    _room_flow_active = true
    _ai_practice_flow_active = false
    _hide_lobby()
    _show_map_selection(true, "房间练习")


func _on_lobby_ai_practice() -> void:
    _room_flow_active = false
    _ai_practice_flow_active = true
    _hide_lobby()
    _show_map_selection(true, "AI练习")


func _on_map_selection_cancelled() -> void:
    _room_flow_active = false
    _ai_practice_flow_active = false
    if _room_battle_ui:
        _room_battle_ui.hide()
    var net: Node = get_node_or_null("/root/RoomNetwork")
    if net and net.is_in_room():
        net.leave_room()
    _show_lobby()


func _on_coming_soon(feature_name: String) -> void:
    _show_toast("%s 即将开放" % feature_name)


func _show_map_selection(practice: bool = false, practice_subtitle: String = "") -> void:
    const MenuBackgroundScript = preload("res://scripts/ui/menu_background.gd")
    MenuBackgroundScript.set_viewport_dim(0.36)
    _hide_lobby()
    if _room_battle_ui:
        _room_battle_ui.hide()
    _play_lobby_bgm()
    if _map_selection:
        _map_selection.reset_to_map_list()
    if _map_selection:
        _map_selection.set_practice_mode(practice, practice_subtitle)
    if _map_selection:
        if practice:
            _map_selection.set_human_silver(GameConstants.PRACTICE_MATCH_SILVER)
        else:
            _map_selection.set_human_silver(_get_persisted_silver())
    if _map_selection:
        _map_selection.show()
    _hide_match_layout()
    _exit_settlement_ui()


func _hide_map_selection() -> void:
    if _map_selection:
        _map_selection.hide()


func _show_match_layout() -> void:
    if _root_margin:
        _root_margin.visible = true
    if _left_panel:
        _left_panel.visible = true
    if _players_list:
        _players_list.visible = true
    if _emote_btn:
        _emote_btn.visible = true


func _hide_match_layout() -> void:
    if _root_margin:
        _root_margin.visible = false
    if _emote_btn:
        _emote_btn.visible = false
    if _settlement_overlay:
        _settlement_overlay.hide()
    _apply_restart_button_placement(RestartBtnPlacement.HIDDEN)


func _on_map_match_confirmed(map_id: String, mode_id: String) -> void:
    if _controller == null:
        return
    if _room_flow_active:
        _on_room_map_confirmed(map_id, mode_id)
        return
    if _ai_practice_flow_active:
        _on_ai_practice_map_confirmed(map_id, mode_id)
        return
    var check: Dictionary = _controller.validate_match_selection(map_id, mode_id)
    if not check.get("ok", false):
        _show_toast(str(check.get("reason", "无法进入该模式")))
        return
    if not _controller.set_match_selection(map_id, mode_id, 0):
        _show_toast("无法进入该模式")
        return
    _controller.set_practice_mode(false)
    _pending_map_id = map_id
    _pending_mode_id = mode_id
    _hide_map_selection()
    _hide_match_layout()
    var map_entry: Dictionary = MapModeConfigScript.get_map(map_id)
    var map_name: String = str(map_entry.get("map_name", map_id))
    if _matchmaking:
        _matchmaking.start_matching(map_name, _get_persisted_silver())


func _on_ai_practice_map_confirmed(map_id: String, mode_id: String) -> void:
    if _controller == null:
        return
    _controller.set_practice_mode(true)
    var check: Dictionary = _controller.validate_match_selection(map_id, mode_id)
    if not check.get("ok", false):
        _show_toast(str(check.get("reason", "无法进入该模式")))
        return
    if not _controller.set_match_selection(map_id, mode_id, 1):
        _show_toast("无法进入该模式")
        return
    _pending_map_id = map_id
    _pending_mode_id = mode_id
    _hide_map_selection()
    _hide_lobby()
    _hide_match_layout()
    _controller.start_match()
    _show_toast("AI练习局开始（免门票、不计盈亏、战利品不入仓库）")


func _on_room_map_confirmed(map_id: String, mode_id: String) -> void:
    if _controller == null:
        return
    if not _controller.set_match_selection(map_id, mode_id, 1):
        _show_toast("无法进入该模式")
        return
    _controller.set_practice_mode(true)
    _pending_map_id = map_id
    _pending_mode_id = mode_id
    _hide_map_selection()
    _hide_match_layout()
    if _room_battle_ui:
        _room_battle_ui.open_hub(map_id, mode_id)


func _on_room_hub_back() -> void:
    _room_flow_active = false
    _show_lobby()


func _on_room_left() -> void:
    pass


func _on_room_network_error(message: String) -> void:
    _show_toast(message)


func _on_room_match_start_requested(payload: Dictionary) -> void:
    if _controller == null:
        return
    var net: Node = get_node_or_null("/root/RoomNetwork")
    if net == null:
        return
    if _room_battle_ui:
        _room_battle_ui.hide()
    _practice_match_active = true
    var seed: int = int(payload.get("seed", -1))
    var map_id: String = str(payload.get("map_id", _pending_map_id))
    var mode_id: String = str(payload.get("mode_id", _pending_mode_id))
    var assignments: Dictionary = payload.get("assignments", {})
    _controller.set_practice_mode(true)
    _controller.set_match_selection(map_id, mode_id, 1)
    _controller.configure_room_network(assignments, true)
    _pending_map_id = map_id
    _pending_mode_id = mode_id
    _hide_lobby()
    _hide_map_selection()
    _controller.start_match(seed)
    _show_toast("房间练习局开始（不计盈亏）")


func _on_matchmaking_finished() -> void:
    if _controller == null:
        return
    _controller.start_match()


func _on_matchmaking_cancelled() -> void:
    _hide_lobby()
    if _map_selection:
        _map_selection.set_human_silver(_get_persisted_silver())
    if _map_selection:
        _map_selection.show()
        move_child(_map_selection, -1)
    _hide_match_layout()


func _setup_emote_bubble() -> void:
    _emote_bubble = EmoteBubbleScript.new()
    add_child(_emote_bubble)


func _get_human_seat_card() -> PlayerSeatCard:
    if _controller == null:
        return null
    var players: Array = _controller.get_players()
    for i in players.size():
        var p = players[i]
        if p.is_human and i < _seat_cards.size():
            return _seat_cards[i]
    return null


func _on_emote_picked(emoji: String, caption: String) -> void:
    var card: PlayerSeatCard = _get_human_seat_card()
    if card == null or _emote_bubble == null:
        return
    var avatar: TextureRect = card.get_avatar_control()
    if avatar:
        _emote_bubble.display_beside_avatar(avatar, card, emoji, caption)


func _setup_background() -> void:
    const MenuBackgroundScript = preload("res://scripts/ui/menu_background.gd")
    MenuBackgroundScript.ensure_main_viewport_background()
    if _bg_texture == null:
        push_warning("MatchUI: BgTexture 未找到，无法设置仓库背景")


func _setup_settlement_canvas_layer() -> void:
    if _settlement_canvas_layer != null or _settlement_overlay == null:
        return
    _settlement_canvas_layer = CanvasLayer.new()
    _settlement_canvas_layer.name = "SettlementLayer"
    _settlement_canvas_layer.layer = 68
    add_child(_settlement_canvas_layer)
    _settlement_canvas_layer.add_child(_settlement_overlay)


func _setup_restart_button_anchor() -> void:
    if _restart_canvas_layer != null:
        return
    _restart_canvas_layer = CanvasLayer.new()
    _restart_canvas_layer.name = "RestartButtonLayer"
    _restart_canvas_layer.layer = 72
    add_child(_restart_canvas_layer)
    _restart_btn_host = Control.new()
    _restart_btn_host.name = "RestartButtonHost"
    _restart_btn_host.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
    _restart_btn_host.offset_top = -96.0
    _restart_btn_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _restart_canvas_layer.add_child(_restart_btn_host)


func _setup_settlement_layout_spacer() -> void:
    if _main_columns == null:
        return
    _settlement_layout_spacer = Control.new()
    _settlement_layout_spacer.name = "SettlementLayoutSpacer"
    _settlement_layout_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _settlement_layout_spacer.visible = false
    _main_columns.add_child(_settlement_layout_spacer)
    _main_columns.move_child(_settlement_layout_spacer, 0)


func _setup_settlement_recycle_bar() -> void:
    if _loot_host == null:
        return
    _settlement_recycle_bar = SettlementRecycleBarScript.new()
    _settlement_recycle_bar.name = "SettlementRecycleBar"
    _settlement_recycle_bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
    _settlement_recycle_bar.offset_top = -56.0
    _settlement_recycle_bar.visible = false
    _loot_host.add_child(_settlement_recycle_bar)
    _settlement_recycle_bar.filter_changed.connect(_on_settlement_recycle_filter_changed)
    _settlement_recycle_bar.recycle_pressed.connect(_on_settlement_recycle_pressed)


func _should_show_settlement_recycle() -> bool:
    if _practice_match_active or (_controller != null and _controller.is_practice_mode()):
        return false
    var net: Node = get_node_or_null("/root/RoomNetwork")
    if net != null and net.is_in_room():
        return false
    if _controller == null or not _controller.did_human_win_auction():
        return false
    return true


func _refresh_settlement_recycle_bar() -> void:
    if _settlement_recycle_bar == null or _controller == null:
        return
    if not _should_show_settlement_recycle() or not _is_settlement_active():
        _settlement_recycle_bar.hide_bar()
        if _loot_panel:
            _loot_panel.offset_bottom = 0.0
        return
    var qualities: Array[int] = _settlement_recycle_bar.get_selected_qualities()
    var count: int = _controller.count_recyclable_items(qualities)
    _settlement_recycle_bar.set_silver_display(_controller.get_human_silver_amount())
    _settlement_recycle_bar.update_recycle_count(count)
    _settlement_recycle_bar.show()
    if _loot_panel:
        _loot_panel.offset_bottom = -58.0


func _on_settlement_recycle_filter_changed(_qualities: Array[int]) -> void:
    _refresh_settlement_recycle_bar()


func _on_settlement_recycle_pressed(qualities: Array[int]) -> void:
    if _controller == null:
        return
    var result: Dictionary = _controller.recycle_items_by_qualities(qualities)
    var count: int = int(result.get("count", 0))
    var silver: int = int(result.get("silver", 0))
    if count <= 0:
        _show_toast("没有符合筛选的藏品可回收")
        _refresh_settlement_recycle_bar()
        return
    if _loot_panel and _controller.get_warehouse():
        _loot_panel.set_catalog(_resolve_item_catalog())
        _loot_panel.set_warehouse(_controller.get_warehouse(), _controller.get_estimated_min_price())
        for i in _controller.get_warehouse().items.size():
            _loot_panel.reveal_item(i)
    _refresh_settlement_recycle_bar()
    _refresh_top_silver()
    _show_toast("已回收 %d 件藏品，获得 %s 银币" % [count, _format_comma(silver)])


func _setup_loot_canvas_layer() -> void:
    _loot_canvas_layer = CanvasLayer.new()
    _loot_canvas_layer.name = "LootFloatLayer"
    _loot_canvas_layer.layer = 32
    _loot_canvas_layer.visible = false
    add_child(_loot_canvas_layer)


func _configure_skill_scroll() -> void:
    if _skill_list == null:
        return
    var scroll: ScrollContainer = _skill_list.get_parent() as ScrollContainer
    if scroll:
        scroll.custom_minimum_size = Vector2(0, 240)
        scroll.size_flags_stretch_ratio = 1.1


func _configure_column_layout() -> void:
    if _main_columns == null:
        return
    var left: Control = _main_columns.get_node_or_null("LeftPanel")
    if left:
        left.size_flags_stretch_ratio = 0.0
    if _center_panel:
        _center_panel.size_flags_stretch_ratio = 0.43
        _center_panel.custom_minimum_size.x = 336
    if _right_panel:
        _right_panel.size_flags_stretch_ratio = 0.50
        _right_panel.custom_minimum_size.x = 336


func _setup_bid_action_row() -> void:
    if _bid_buttons_row == null or _bid_area == null:
        return
    _item_btn.visible = false
    _pass_btn.visible = false
    _raise_btn.visible = true
    _raise_btn.text = "出价"
    _style_bid_action_buttons()
    if _forfeit_btn.get_parent() == _bid_area:
        _bid_area.remove_child(_forfeit_btn)
        _bid_buttons_row.add_child(_forfeit_btn)
    _forfeit_btn.text = "弃权本局"
    _forfeit_btn.custom_minimum_size = Vector2(0, 52)
    _forfeit_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _forfeit_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    _forfeit_btn.size_flags_stretch_ratio = 0.42
    if _restart_btn:
        _reparent_restart_btn(_bid_buttons_row)
        _restart_btn.text = "重新游戏"
        _restart_btn.custom_minimum_size = Vector2(0, 52)
        _restart_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        _restart_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
        _restart_btn.size_flags_stretch_ratio = 0.42
        _restart_btn.visible = false
    _raise_btn.custom_minimum_size = Vector2(0, 52)
    _raise_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _raise_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    _raise_btn.size_flags_stretch_ratio = 0.58
    _bid_buttons_row.alignment = BoxContainer.ALIGNMENT_CENTER
    _bid_buttons_row.add_theme_constant_override("separation", 12)
    var slot_idx: int = _bid_buttons_row.get_index()
    _bid_area.remove_child(_bid_buttons_row)
    _bid_buttons_host = Control.new()
    _bid_buttons_host.clip_contents = false
    _bid_buttons_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _bid_buttons_host.custom_minimum_size = Vector2(0, 72)
    _bid_area.add_child(_bid_buttons_host)
    _bid_area.move_child(_bid_buttons_host, slot_idx)
    _bid_buttons_host.add_child(_bid_buttons_row)
    _bid_buttons_row.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
    _bid_buttons_row.offset_bottom = 72.0
    call_deferred("_sync_bid_buttons_host_height")


func _setup_bid_popup() -> void:
    _bid_input.visible = false
    _bid_overlay = Control.new()
    _bid_overlay.name = "BidOverlay"
    _bid_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _bid_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _bid_overlay.visible = false
    _bid_overlay.z_index = 150
    add_child(_bid_overlay)
    _bid_numpad = BidNumpadScript.new()
    _bid_numpad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _bid_numpad.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
    _bid_numpad.confirm_pressed.connect(_on_bid_popup_confirm)
    _bid_numpad.amount_changed.connect(_on_numpad_amount_changed)
    _bid_popup = PanelContainer.new()
    _bid_popup.visible = false
    _bid_popup.clip_contents = false
    _bid_popup.mouse_filter = Control.MOUSE_FILTER_STOP
    var pop_sb := StyleBoxFlat.new()
    pop_sb.bg_color = Color(0.06, 0.07, 0.1, 0.98)
    pop_sb.border_color = Color(0.22, 0.28, 0.38, 0.9)
    pop_sb.set_border_width_all(1)
    pop_sb.set_corner_radius_all(8)
    pop_sb.content_margin_left = 8
    pop_sb.content_margin_right = 8
    pop_sb.content_margin_top = 6
    pop_sb.content_margin_bottom = 8
    _bid_popup.add_theme_stylebox_override("panel", pop_sb)
    var pop_vbox := VBoxContainer.new()
    pop_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
    pop_vbox.add_theme_constant_override("separation", 6)
    _bid_popup.add_child(pop_vbox)
    var pop_header := HBoxContainer.new()
    pop_vbox.add_child(pop_header)
    var pop_title := Label.new()
    pop_title.text = "输入出价"
    pop_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    pop_title.add_theme_font_size_override("font_size", 15)
    pop_header.add_child(pop_title)
    _bid_popup_timer = Label.new()
    _bid_popup_timer.text = ""
    _bid_popup_timer.add_theme_font_size_override("font_size", 16)
    _bid_popup_timer.add_theme_color_override("font_color", BID_TIMER_NORMAL_COLOR)
    pop_header.add_child(_bid_popup_timer)
    _bid_popup_close_btn = UiCloseButtonScript.append_to_header(pop_header, _close_bid_popup, Vector2(40, 40))
    pop_vbox.add_child(_bid_numpad)
    var pass_row := HBoxContainer.new()
    pass_row.alignment = BoxContainer.ALIGNMENT_CENTER
    pop_vbox.add_child(pass_row)
    var pass_btn := Button.new()
    pass_btn.text = "本轮不出价"
    pass_btn.custom_minimum_size = Vector2(0, 44)
    pass_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    UiButtonStyleScript.apply(pass_btn)
    pass_btn.pressed.connect(_on_pass_from_popup)
    pass_row.add_child(pass_btn)
    _bid_overlay.add_child(_bid_popup)
    FontUtilScript.apply_cjk_font(_bid_popup, 14)


func _sync_bid_buttons_host_height() -> void:
    if _bid_buttons_host == null or _bid_buttons_row == null:
        return
    var row_h: float = maxf(_bid_buttons_row.get_combined_minimum_size().y, 64.0)
    _bid_buttons_host.custom_minimum_size.y = row_h
    _bid_buttons_row.offset_bottom = row_h
    call_deferred("_style_bid_action_buttons")


func _on_match_ui_resized() -> void:
    if _bid_popup != null and _bid_popup.visible:
        _layout_bid_popup()


func _bid_popup_min_height() -> float:
    var h: float = 72.0
    if _bid_numpad:
        h += _bid_numpad.get_combined_minimum_size().y
    return h


func _layout_bid_popup() -> void:
    if _bid_popup == null or _bid_overlay == null or _center_panel == null:
        return
    call_deferred("_apply_bid_popup_rect")
    call_deferred("_apply_bid_popup_rect_late")


func _apply_bid_popup_rect_late() -> void:
    if _bid_overlay != null and _bid_overlay.visible:
        _apply_bid_popup_rect()


func _apply_bid_popup_rect() -> void:
    if _bid_popup == null or _bid_overlay == null or _center_panel == null:
        return
    if not _bid_overlay.visible:
        return
    var overlay_size: Vector2 = _bid_overlay.size
    if overlay_size.y < 32.0:
        return
    var center_rect: Rect2 = _center_panel.get_global_rect()
    var overlay_rect: Rect2 = _bid_overlay.get_global_rect()
    var local_x: float = center_rect.position.x - overlay_rect.position.x
    var pop_w: float = maxf(center_rect.size.x - 12.0, 300.0)
    var margin_bottom: float = 16.0
    var margin_top: float = 48.0
    var min_h: float = _bid_popup_min_height()
    var anchor_bottom: float = overlay_size.y - margin_bottom
    if _bid_buttons_host:
        var host_rect: Rect2 = _bid_buttons_host.get_global_rect()
        if host_rect.size.y > 0.0:
            anchor_bottom = host_rect.position.y - overlay_rect.position.y + host_rect.size.y
    var viewport_bottom: float = overlay_size.y - margin_bottom
    anchor_bottom = minf(anchor_bottom, viewport_bottom)
    var max_h: float = maxf(anchor_bottom - margin_top, min_h)
    var pop_h: float = clampf(maxf(min_h, 268.0), min_h, max_h)
    var pop_y: float = anchor_bottom - pop_h
    if pop_y < margin_top:
        pop_y = margin_top
        pop_h = minf(max_h, anchor_bottom - pop_y)
        pop_h = maxf(pop_h, min_h)
    _bid_popup.set_anchors_preset(Control.PRESET_TOP_LEFT)
    _bid_popup.position = Vector2(local_x + 6.0, pop_y)
    _bid_popup.size = Vector2(pop_w, pop_h)
    if _bid_numpad:
        _bid_numpad.queue_redraw()


func _on_pass_from_popup() -> void:
    _close_bid_popup()
    _on_pass_pressed()


func _on_open_bid_popup_pressed() -> void:
    if _raise_btn.disabled:
        return
    _refresh_bid_numpad_limits()
    if _bid_numpad:
        _bid_numpad.set_amount_text("")
    _sync_bid_buttons_host_height()
    if _bid_overlay:
        _bid_overlay.visible = true
        _bid_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
    if _bid_popup:
        _bid_popup.visible = true
        _bid_popup.move_to_front()
    _layout_bid_popup()
    if _bid_numpad:
        _bid_numpad.call_deferred("focus_amount_input")


func _close_bid_popup() -> void:
    if _bid_popup:
        _bid_popup.visible = false
    if _bid_overlay:
        _bid_overlay.visible = false
        _bid_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _on_bid_popup_confirm() -> void:
    _submit_bid_from_input()
    _close_bid_popup()


func _on_numpad_amount_changed(text: String) -> void:
    _bid_input.text = text


func _refresh_bid_numpad_limits() -> void:
    if _bid_numpad == null or _controller == null:
        return
    for p in _controller.get_players():
        if p.is_human:
            _bid_numpad.set_silver_max(p.silver)
            break
    _bid_numpad.set_last_round_bid(_get_human_last_round_bid())
    var round_idx: int = _controller.get_round_index()
    if round_idx >= 1:
        _bid_numpad.set_multiplier(_controller.get_instant_kill_multiplier_for_round(round_idx))


func _get_human_last_round_bid() -> int:
    if _controller == null:
        return 0
    var prev_round: int = _controller.get_round_index() - 1
    if prev_round < 1:
        return 0
    for p in _controller.get_players():
        if not p.is_human:
            continue
        var idx: int = prev_round - 1
        if idx >= 0 and idx < p.round_bids.size():
            return int(p.round_bids[idx])
    return 0


func _style_transparent_panels() -> void:
    var columns: HBoxContainer = $RootMargin/RootVBox/MainColumns
    var left: PanelContainer = columns.get_node("LeftPanel") as PanelContainer
    var center: PanelContainer = columns.get_node("CenterPanel") as PanelContainer
    var right: PanelContainer = columns.get_node("RightPanel") as PanelContainer
    var left_sb := StyleBoxFlat.new()
    left_sb.bg_color = Color(0.05, 0.06, 0.09, 0.62)
    left_sb.border_color = Color(0.25, 0.32, 0.42, 0.55)
    left_sb.set_border_width_all(1)
    left_sb.set_corner_radius_all(6)
    left.add_theme_stylebox_override("panel", left_sb)
    var center_sb := center.get_theme_stylebox("panel")
    if center_sb is StyleBoxFlat:
        var dup: StyleBoxFlat = center_sb.duplicate() as StyleBoxFlat
        dup.bg_color.a = 0.58
        center.add_theme_stylebox_override("panel", dup)
    var right_sb := StyleBoxFlat.new()
    right_sb.bg_color = Color(0.05, 0.06, 0.09, 0.62)
    right_sb.border_color = Color(0.25, 0.32, 0.42, 0.55)
    right_sb.set_border_width_all(1)
    right_sb.set_corner_radius_all(6)
    right.add_theme_stylebox_override("panel", right_sb)


func _resolve_item_catalog():
    if _controller != null:
        var from_match = _controller.get_catalog()
        if from_match != null and from_match.is_loaded():
            return from_match
    if _menu_catalog == null:
        _menu_catalog = ItemCatalogScript.new()
        if not _menu_catalog.load_all():
            return null
    if _menu_catalog.is_loaded():
        return _menu_catalog
    return null


func _setup_encyclopedia() -> void:
    var catalog = _resolve_item_catalog()
    if catalog == null:
        return
    if _encyclopedia != null and is_instance_valid(_encyclopedia):
        return
    _encyclopedia = ItemEncyclopediaScript.new(catalog)
    add_child(_encyclopedia)
    _encyclopedia.hide()
    if not _encyclopedia.closed.is_connected(_on_encyclopedia_closed):
        _encyclopedia.closed.connect(_on_encyclopedia_closed)
    if _loot_panel:
        var wiki_btn: Button = _loot_panel.get_wiki_button()
        if wiki_btn and not wiki_btn.pressed.is_connected(_on_open_encyclopedia):
            wiki_btn.pressed.connect(_on_open_encyclopedia)


func _on_open_collection() -> void:
    if _collection_ui == null:
        _show_toast("收藏界面未初始化")
        return
    var catalog = _resolve_item_catalog()
    if catalog == null:
        _show_toast("道具数据加载中，请稍后重试")
        return
    _collection_ui.setup(catalog)
    _hide_lobby()
    _hide_map_selection()
    _hide_match_layout()
    if _matchmaking:
        _matchmaking.hide()
    _collection_ui.show()
    _collection_ui.open()
    _collection_ui.move_to_front()


func _on_collection_closed() -> void:
    _show_lobby()


func _on_open_characters() -> void:
    var char_ui: CharacterSelectionUI = _character_ui as CharacterSelectionUI
    if char_ui == null:
        _show_toast("角色界面未初始化")
        return
    _hide_lobby()
    _hide_map_selection()
    _hide_match_layout()
    if _matchmaking:
        _matchmaking.hide()
    char_ui.open()
    char_ui.move_to_front()


func _on_characters_closed() -> void:
    _show_lobby()


func _setup_leaderboard() -> void:
    _leaderboard_ui = LeaderboardUIScript.new()
    _leaderboard_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(_leaderboard_ui)
    move_child(_leaderboard_ui, -1)
    _leaderboard_ui.closed.connect(_on_leaderboard_closed)
    _leaderboard_ui.hide()


func _on_open_leaderboard() -> void:
    if _leaderboard_ui == null:
        _show_toast("排行榜未初始化")
        return
    _hide_lobby()
    _hide_map_selection()
    _hide_match_layout()
    if _matchmaking:
        _matchmaking.hide()
    _leaderboard_ui.open()
    _leaderboard_ui.move_to_front()


func _on_leaderboard_closed() -> void:
    _show_lobby()


func _setup_warehouse() -> void:
    _warehouse_ui = WarehouseUIScript.new()
    _warehouse_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(_warehouse_ui)
    move_child(_warehouse_ui, -1)
    _warehouse_ui.closed.connect(_on_warehouse_closed)
    _warehouse_ui.shop_requested.connect(_on_open_shop)
    _warehouse_ui.hide()


func _setup_shop() -> void:
    _shop_ui = ShopUIScript.new()
    _shop_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(_shop_ui)
    move_child(_shop_ui, -1)
    _shop_ui.closed.connect(_on_shop_closed)
    _shop_ui.warehouse_refresh_requested.connect(_on_shop_warehouse_refresh)
    _shop_ui.hide()


func _on_open_warehouse() -> void:
    if _warehouse_ui == null:
        _show_toast("仓库未初始化")
        return
    var catalog = _resolve_item_catalog()
    if catalog == null:
        _show_toast("道具数据加载中，请稍后重试")
        return
    _warehouse_ui.setup(catalog)
    if _matchmaking:
        _matchmaking.hide()
    _warehouse_ui.open()
    _warehouse_ui.move_to_front()


func _on_warehouse_closed() -> void:
    if _lobby and _lobby.visible:
        _lobby.refresh_portfolio()
    elif _root_margin and _root_margin.visible:
        pass
    else:
        _show_lobby()


func _on_open_shop() -> void:
    if _shop_ui == null:
        _show_toast("商店未初始化")
        return
    var catalog = _resolve_item_catalog()
    if catalog == null:
        _show_toast("道具数据加载中，请稍后重试")
        return
    _shop_ui.setup(catalog, Callable(self, "_show_toast"))
    _hide_lobby()
    _hide_map_selection()
    _hide_match_layout()
    if _matchmaking:
        _matchmaking.hide()
    if _warehouse_ui and _warehouse_ui.visible:
        _warehouse_ui.hide()
    _shop_ui.open()
    _shop_ui.move_to_front()


func _on_shop_closed() -> void:
    _show_lobby()


func _on_shop_warehouse_refresh() -> void:
    if _warehouse_ui and _warehouse_ui.is_visible_in_tree():
        _warehouse_ui.open()


func _deposit_won_loot_to_player() -> int:
    if _practice_match_active or (_controller and _controller.is_practice_mode()):
        return 0
    if _controller == null or not _controller.did_human_win_auction():
        return 0
    var wh = _controller.get_warehouse()
    var catalog = _controller.get_catalog()
    if wh == null or catalog == null:
        return 0
    var warehouse: Node = get_node_or_null("/root/PlayerWarehouse")
    var collection: Node = get_node_or_null("/root/PlayerCollection")
    var added: int = 0
    if warehouse:
        added = warehouse.deposit_match_warehouse(wh, catalog)
    if collection:
        for item in wh.items:
            if item.quality == GameConstants.Quality.RED:
                collection.record_red_item(str(item.item_id))
    return added


func _on_character_selected(_character_id: String) -> void:
    _show_toast("已切换出战角色")
    if _lobby:
        _lobby.refresh_portfolio()


func _on_open_encyclopedia() -> void:
    if _encyclopedia == null or not is_instance_valid(_encyclopedia):
        _setup_encyclopedia()
    if _encyclopedia == null:
        _show_toast("藏品百科加载失败")
        return
    _hide_lobby()
    _hide_map_selection()
    _hide_match_layout()
    if _matchmaking:
        _matchmaking.hide()
    _bring_encyclopedia_to_front()
    _encyclopedia.show()
    _encyclopedia.open()


func _is_settlement_active() -> bool:
    return _settlement_overlay != null and _settlement_overlay.visible


func _bring_encyclopedia_to_front() -> void:
    if _encyclopedia == null:
        return
    _encyclopedia.layer = (
        ItemEncyclopediaScript.LAYER_ABOVE_SETTLEMENT
        if _is_settlement_active()
        else ItemEncyclopediaScript.LAYER_NORMAL
    )
    if _is_settlement_active() and _loot_canvas_layer:
        _loot_canvas_layer.visible = false


func _on_encyclopedia_closed() -> void:
    if _is_settlement_active():
        if _right_panel_reparented and _loot_canvas_layer:
            _loot_canvas_layer.visible = true
        return
    if _is_match_in_progress():
        _show_match_layout()
        if _controller:
            _on_phase_changed(_controller.get_phase(), _controller.get_round_index())
            _sync_player_sidebar()
        return
    if _lobby and _lobby.visible:
        return
    _show_lobby()


func bind_controller(controller) -> void:
    _controller = controller
    _bind_controller(controller)
    _setup_encyclopedia()


func _bind_controller(controller) -> void:
    if _controller_signals_bound:
        return
    _controller_signals_bound = true
    controller.phase_changed.connect(_on_phase_changed)
    controller.log_message.connect(_on_log)
    controller.open_board_updated.connect(_on_board_updated)
    controller.bid_window_tick.connect(_on_bid_tick)
    controller.bid_window_waiting.connect(_on_bid_waiting)
    controller.player_bid_result.connect(_on_player_bid_result)
    controller.match_forfeit_changed.connect(_on_match_forfeit_changed)
    controller.item_revealed.connect(_on_item_revealed)
    controller.settlement_tick.connect(_on_settlement_tick)
    controller.settlement_ready.connect(_on_settlement_ready)
    controller.match_settled.connect(_on_match_settled)
    controller.match_started.connect(_on_match_started)
    controller.round_closed.connect(_on_round_closed)
    controller.skill_effects_updated.connect(_on_skill_effects)
    controller.skill_effects_reset.connect(_on_skill_effects_reset)
    controller.skill_effect_appended.connect(_on_skill_effect_appended)
    controller.intel_items_revealed.connect(_on_intel_items_revealed)
    controller.intel_outlines_revealed.connect(_on_intel_outlines_revealed)
    controller.quality_size_revealed.connect(_on_quality_size_revealed)
    controller.bid_window_finished.connect(_on_bid_window_finished)
    controller.cinematic_requested.connect(_on_cinematic_requested)


func _on_cinematic_requested(payload: Dictionary) -> void:
    if _cinematic_overlay == null:
        _cinematic_overlay = MatchCinematicOverlayScript.new()
        add_child(_cinematic_overlay)
    _set_match_layout_hidden_for_cinematic(true)
    var type_name: String = str(payload.get("type", ""))
    if type_name == "_sequence":
        await _cinematic_overlay.play_sequence(payload.get("sequence", []))
    else:
        var opts: Dictionary = payload.get("options", {})
        await _cinematic_overlay.play(payload, opts)
        if not bool(opts.get("fade_out", true)):
            _cinematic_overlay.dismiss_instant()
    _set_match_layout_hidden_for_cinematic(false)
    if _controller:
        _controller.notify_cinematic_finished()


func _set_match_layout_hidden_for_cinematic(hidden: bool) -> void:
    if hidden:
        if _layout_hidden_for_cinematic:
            return
        _layout_hidden_for_cinematic = true
        if _root_margin:
            _root_margin.visible = false
        return
    _layout_hidden_for_cinematic = false
    if _root_margin and _controller and _controller.get_phase() != GameConstants.MatchPhase.LOBBY:
        _root_margin.visible = true
    if _controller:
        _on_phase_changed(_controller.get_phase(), _controller.get_round_index())
        _sync_player_sidebar()


func _on_match_started() -> void:
    if not _controller:
        return
    const MenuBackgroundScript = preload("res://scripts/ui/menu_background.gd")
    MenuBackgroundScript.clear_viewport_dim()
    _show_match_layout()
    _play_map_bgm(_pending_map_id)
    _forfeited = false
    _human_locked_this_round = false
    _settlement_claimed = false
    _apply_restart_button_placement(RestartBtnPlacement.HIDDEN)
    _exit_settlement_ui()
    if _settlement_overlay:
        _settlement_overlay.hide()
    _refresh_top_silver()
    _refresh_bid_numpad_limits()
    _top_gold.text = "0"
    _loot_panel.set_catalog(_resolve_item_catalog())
    _loot_panel.set_warehouse(_controller.get_warehouse(), 0)
    _sync_player_sidebar()
    call_deferred("_sync_player_sidebar")
    _on_skill_effects_reset()
    _on_phase_changed(_controller.get_phase(), _controller.get_round_index())


func _on_phase_changed(phase: int, round_index: int) -> void:
    if phase == GameConstants.MatchPhase.UNBOX or phase == GameConstants.MatchPhase.SETTLEMENT:
        _round_banner.text = "对局结束"
        _update_instant_kill_banner(0)
        _set_bid_controls_enabled(false)
        if _bid_area:
            _bid_area.visible = false
        _update_round_header_visibility(phase, round_index)
        return
    if _bid_area:
        _bid_area.visible = phase != GameConstants.MatchPhase.INFO
    if round_index >= 1:
        _round_banner.text = "第%d轮" % round_index
        _update_instant_kill_banner(round_index)
    else:
        _round_banner.text = ""
        _update_instant_kill_banner(0)
    _update_round_header_visibility(phase, round_index)
    if phase == GameConstants.MatchPhase.BID_WINDOW:
        _human_locked_this_round = false
        _bid_status.text = ""
        _refresh_bid_numpad_limits()
        if _bid_numpad:
            _bid_numpad.set_amount_text("")
    else:
        _close_bid_popup()
        _clear_bid_timer_display()
    _set_bid_controls_enabled(phase == GameConstants.MatchPhase.BID_WINDOW)
    if phase == GameConstants.MatchPhase.LOBBY:
        _clear_player_cards()


func _on_board_updated(board) -> void:
    if board == null:
        return
    if _min_bid_label:
        _min_bid_label.visible = false
    if _bid_input.text.is_empty() and not _human_locked_this_round:
        _bid_input.placeholder_text = "输入出价金额"
    _refresh_player_cards(
        _resolve_leader_seat_for_ui(),
        _controller.get_round_index() if _controller else 1,
        _hide_current_round_bids(),
    )


func _hide_current_round_bids() -> bool:
    if _controller == null:
        return false
    var board = _controller.get_board()
    if board == null:
        return false
    return _controller.get_phase() == GameConstants.MatchPhase.BID_WINDOW and board.window_active


func _on_bid_tick(seconds_left: float) -> void:
    var secs: int = int(ceil(maxf(seconds_left, 0.0)))
    _bid_timer.text = "%s%d" % [BID_TIMER_PREFIX, secs]
    var urgent: bool = seconds_left <= BID_TIMER_URGENT_SECONDS
    _apply_bid_timer_style(urgent)
    if _bid_popup_timer:
        _bid_popup_timer.text = "倒计时：%d" % secs
        var color: Color = BID_TIMER_URGENT_COLOR if urgent else BID_TIMER_NORMAL_COLOR
        _bid_popup_timer.add_theme_color_override("font_color", color)


func _apply_bid_timer_style(urgent: bool) -> void:
    if _bid_timer == null:
        return
    if urgent:
        _bid_timer.add_theme_font_size_override(
            "font_size", BID_TIMER_BASE_FONT_SIZE + BID_TIMER_URGENT_FONT_BONUS,
        )
        _bid_timer.add_theme_color_override("font_color", BID_TIMER_URGENT_COLOR)
    else:
        _reset_bid_timer_style()


func _reset_bid_timer_style() -> void:
    if _bid_timer == null:
        return
    _bid_timer.add_theme_font_size_override("font_size", BID_TIMER_BASE_FONT_SIZE)
    _bid_timer.add_theme_color_override("font_color", BID_TIMER_NORMAL_COLOR)


func _clear_bid_timer_display() -> void:
    if _bid_timer == null:
        return
    _bid_timer.text = ""
    _reset_bid_timer_style()
    if _bid_popup_timer:
        _bid_popup_timer.text = ""
        _bid_popup_timer.add_theme_color_override("font_color", BID_TIMER_NORMAL_COLOR)


func _on_bid_waiting(done_count: int, total: int) -> void:
    if total <= 0:
        _bid_status.text = "等待房主结算本轮…"
        return
    if done_count >= total:
        _bid_status.text = "全员已出价，结算本轮…"
    elif _forfeited:
        _bid_status.text = "已弃权 · 观战中 (%d/%d 已完成)" % [done_count, total]
    elif _human_locked_this_round:
        _bid_status.text = "等待其他玩家 (%d/%d)" % [done_count, total]
    else:
        _bid_status.text = "请在倒计时内出价 (%d/%d 已完成)" % [done_count, total]
    if _controller:
        var leader: int = -1
        if _controller.get_board():
            leader = _controller.get_board().current_leader_seat
        _refresh_player_cards(
            _resolve_leader_seat_for_ui(),
            _controller.get_round_index(),
            _hide_current_round_bids(),
        )


func _on_round_closed(closed_round: int) -> void:
    _human_locked_this_round = false
    if _controller:
        _refresh_player_cards(
            _resolve_leader_seat_for_ui(),
            closed_round,
            false,
        )


func _on_skill_effects_reset() -> void:
    for c in _skill_list.get_children():
        c.queue_free()


func _on_skill_effect_appended(effect: Dictionary) -> void:
    _skill_list.add_child(_make_effect_row(effect))


func _on_skill_effects(effects: Array) -> void:
    _on_skill_effects_reset()
    for e in effects:
        _skill_list.add_child(_make_effect_row(e))


func _on_intel_outlines_revealed(indices: Array) -> void:
    if _loot_panel and not indices.is_empty():
        _loot_panel.reveal_outline_items(indices)
    _refresh_loot_estimate()


func _on_intel_items_revealed(indices: Array) -> void:
    if _loot_panel and not indices.is_empty():
        _loot_panel.reveal_intel_items(indices)
    _refresh_loot_estimate()


func _on_quality_size_revealed(indices: Array) -> void:
    if _loot_panel and not indices.is_empty():
        _loot_panel.reveal_quality_size_items(indices)
    _refresh_loot_estimate()


func _on_bid_window_finished(round_index: int) -> void:
    _close_bid_popup()
    _bid_status.text = "第%d轮出价完成" % round_index
    _clear_bid_timer_display()
    _set_bid_controls_enabled(false)
    if _controller:
        var leader: int = -1
        if _controller.get_board():
            leader = _controller.get_board().current_leader_seat
        _refresh_player_cards(_resolve_leader_seat_for_ui(), round_index, false)


func _format_instant_kill_multiplier(mult: float) -> String:
    if absf(mult - roundf(mult)) < 0.001:
        return "%d倍" % int(roundf(mult))
    var one_decimal: String = "%.1f" % mult
    if one_decimal.ends_with(".0"):
        return "%d倍" % int(roundf(mult))
    return "%s倍" % one_decimal


func _update_round_header_visibility(phase: int, round_index: int = 1) -> void:
    var show_header: bool = round_index >= 1 and (
        phase == GameConstants.MatchPhase.INFO
        or phase == GameConstants.MatchPhase.BID_WINDOW
        or phase == GameConstants.MatchPhase.OPEN_BOARD
        or phase == GameConstants.MatchPhase.BID_RESOLVE
        or phase == GameConstants.MatchPhase.UNBOX
        or phase == GameConstants.MatchPhase.SETTLEMENT
    )
    if _round_banner:
        _round_banner.get_parent().visible = show_header
    if _instant_kill_banner and not show_header:
        _instant_kill_banner.visible = false


func _update_instant_kill_banner(round_index: int) -> void:
    if _instant_kill_banner == null:
        return
    if round_index < 1:
        _instant_kill_banner.text = ""
        _instant_kill_banner.visible = false
        return
    var mult: float = 1.0
    if _controller:
        mult = _controller.get_instant_kill_multiplier_for_round(round_index)
    _instant_kill_banner.text = "秒杀倍率：%s" % _format_instant_kill_multiplier(mult)
    _instant_kill_banner.visible = true


func _make_effect_row(effect: Dictionary) -> PanelContainer:
    var panel := PanelContainer.new()
    var sb := StyleBoxFlat.new()
    var is_teaser: bool = bool(effect.get("is_teaser", false))
    if is_teaser:
        sb.bg_color = Color(0.08, 0.1, 0.14, 0.92)
        sb.border_color = Color(0.45, 0.52, 0.62, 0.85)
        sb.set_border_width_all(1)
    else:
        sb.bg_color = Color(0.1, 0.12, 0.16, 0.85)
    sb.set_corner_radius_all(4)
    sb.content_margin_left = 10
    sb.content_margin_right = 10
    sb.content_margin_top = 8
    sb.content_margin_bottom = 8
    panel.add_theme_stylebox_override("panel", sb)
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 10)
    panel.add_child(row)
    var icon := TextureRect.new()
    icon.custom_minimum_size = Vector2(36, 36)
    icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    var icon_kind: String = str(effect.get("icon_kind", ""))
    if icon_kind == "warehouse":
        var wh_tex: Texture2D = UiTextureCacheScript.get_warehouse_bg()
        if wh_tex:
            icon.texture = wh_tex
    elif icon_kind == "character":
        const RosterConfigScript = preload("res://scripts/data/roster_config.gd")
        var cid: String = str(effect.get("character_id", ""))
        if not cid.is_empty():
            var portrait: String = RosterConfigScript.get_portrait_path(cid)
            if ResourceLoader.exists(portrait):
                icon.texture = load(portrait)
    if icon.texture == null:
        var ph := ColorRect.new()
        ph.color = Color(0.55, 0.4, 0.7)
        ph.custom_minimum_size = Vector2(36, 36)
        row.add_child(ph)
    row.add_child(icon)
    var texts := VBoxContainer.new()
    texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_child(texts)
    var body_bbcode: String = str(effect.get("body_bbcode", ""))
    if not is_teaser and not body_bbcode.is_empty():
        var body_rt := RichTextLabel.new()
        body_rt.bbcode_enabled = true
        body_rt.fit_content = true
        body_rt.scroll_active = false
        body_rt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        body_rt.add_theme_color_override("default_color", Color(0.88, 0.9, 0.95))
        body_rt.add_theme_font_size_override("normal_font_size", 14)
        body_rt.text = body_bbcode
        texts.add_child(body_rt)
    else:
        var title := Label.new()
        var line: String = (
            MatchIntelScript.format_effect_line(effect)
            if not is_teaser
            else str(effect.get("title", ""))
        )
        title.text = line
        title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        title.add_theme_font_size_override("font_size", 15)
        if is_teaser:
            title.add_theme_color_override("font_color", Color(0.95, 0.96, 1.0))
        texts.add_child(title)
        var detail: String = str(effect.get("detail", "")).strip_edges()
        if not is_teaser and not detail.is_empty() and detail != line:
            var body := Label.new()
            body.text = detail
            body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
            body.add_theme_color_override("font_color", Color(0.75, 0.78, 0.85))
            body.add_theme_font_size_override("font_size", 13)
            texts.add_child(body)
    return panel


func _on_item_revealed(
    _winner: int,
    quality: int,
    _value: int,
    item_index: int,
    _total: int,
    _item_name: String,
) -> void:
    _loot_panel.reveal_item(item_index)
    _refresh_loot_estimate()
    # 红色藏品仅在结算领取且人类拍得整仓时写入（见 _deposit_won_loot_to_player）


func _refresh_loot_estimate() -> void:
    if _loot_panel and _controller:
        _loot_panel.update_estimate(_controller.get_estimated_min_price())


func _on_settlement_tick(tick: Dictionary) -> void:
    if _settlement_overlay == null:
        return
    _apply_settlement_background_style(true)
    _close_bid_popup()
    if _bid_area:
        _bid_area.visible = false
    _set_bid_controls_enabled(false)
    _set_settlement_columns_visible(false)
    _settlement_overlay.show()
    if _settlement_canvas_layer:
        _settlement_canvas_layer.visible = true
    if _encyclopedia and _encyclopedia.visible:
        _bring_encyclopedia_to_front()
    var phase: String = str(tick.get("phase", ""))
    var winner: Dictionary = _winner_info_from_tick(tick)
    if phase == "start":
        _refresh_settlement_recycle_bar()
        _settlement_overlay.begin_settlement(
            int(tick.get("winning_bid", 0)),
            str(winner.get("name", "")),
            int(winner.get("seat", -1)),
            str(winner.get("title", "")),
            str(winner.get("character_id", tick.get("winner_character_id", ""))),
        )
    elif phase == "item" or phase == "done":
        _settlement_overlay.apply_tick(tick)
        _refresh_settlement_recycle_bar()


func _on_settlement_ready(result) -> void:
    _last_settlement_result = result
    _settlement_claimed = false
    var human_won: bool = _human_can_claim_settlement(result)
    if _settlement_overlay:
        if human_won:
            _settlement_overlay.show_final(result, true)
        else:
            if _controller:
                _controller.claim_settlement_rewards()
                _persist_portfolio_from_match()
                _record_leaderboard_match()
            _settlement_claimed = true
            _settlement_overlay.show_final_continue(result)
    if _encyclopedia and _encyclopedia.visible:
        _bring_encyclopedia_to_front()
    _apply_restart_button_placement(RestartBtnPlacement.SETTLEMENT_BOTTOM)


func _human_can_claim_settlement(_result) -> bool:
    if _controller == null:
        return false
    return _controller.did_human_win_auction()


func _is_match_ended_phase() -> bool:
    if _controller == null:
        return false
    var phase: int = _controller.get_phase()
    return (
        phase == GameConstants.MatchPhase.UNBOX
        or phase == GameConstants.MatchPhase.SETTLEMENT
        or phase == GameConstants.MatchPhase.MATCH_END
    )


func _set_settlement_columns_visible(visible: bool) -> void:
    if _settlement_layout_spacer:
        _settlement_layout_spacer.visible = not visible
    if _left_panel:
        _left_panel.visible = visible
    if _center_panel:
        _center_panel.visible = visible
    if visible:
        _restore_right_panel_parent()
    else:
        _float_right_panel_above_settlement()


func _float_right_panel_above_settlement() -> void:
    if _right_panel == null or _loot_canvas_layer == null or _right_panel_reparented:
        return
    if _right_panel.get_parent() != _main_columns:
        return
    _right_panel.reparent(_loot_canvas_layer, true)
    _right_panel_reparented = true
    _loot_canvas_layer.visible = true
    if _loot_host:
        _loot_host.z_index = 0


func _restore_right_panel_parent() -> void:
    if _right_panel == null or not _right_panel_reparented or _main_columns == null:
        return
    if _right_panel.get_parent() != _loot_canvas_layer:
        _right_panel_reparented = false
        if _loot_canvas_layer:
            _loot_canvas_layer.visible = false
        return
    _right_panel.reparent(_main_columns, true)
    _main_columns.move_child(_right_panel, -1)
    _right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _right_panel.size_flags_stretch_ratio = 0.50
    _right_panel_reparented = false
    if _loot_canvas_layer:
        _loot_canvas_layer.visible = false


func _winner_info_from_tick(tick: Dictionary) -> Dictionary:
    var name: String = str(tick.get("winner_name", ""))
    var seat: int = int(tick.get("winner_seat", -1))
    var title: String = str(tick.get("winner_title", ""))
    var character_id: String = str(tick.get("winner_character_id", ""))
    if not name.is_empty():
        return {"name": name, "seat": seat, "title": title, "character_id": character_id}
    if seat >= 0:
        return _winner_info_from_seat(seat)
    return {"name": "", "seat": -1, "title": "", "character_id": ""}


func _winner_info_from_seat(seat: int) -> Dictionary:
    if _controller == null or seat < 0:
        return {"name": "", "seat": seat, "title": "", "character_id": ""}
    for p in _controller.get_players():
        if p.seat_index == seat:
            return {
                "name": p.display_name,
                "seat": seat,
                "title": p.character_title,
                "character_id": p.character_id,
            }
    return {"name": "", "seat": seat, "title": "", "character_id": ""}


func _exit_settlement_ui() -> void:
    if _settlement_recycle_bar:
        _settlement_recycle_bar.hide_bar()
    if _loot_panel:
        _loot_panel.offset_bottom = 0.0
    _apply_settlement_background_style(false)
    _set_settlement_columns_visible(true)


func _apply_settlement_background_style(in_settlement: bool) -> void:
    if _right_panel == null:
        return
    var sb: StyleBox = _right_panel.get_theme_stylebox("panel")
    if sb == null or not sb is StyleBoxFlat:
        return
    if _right_panel_style_normal == null:
        _right_panel_style_normal = (sb as StyleBoxFlat).duplicate() as StyleBoxFlat
    var dup: StyleBoxFlat = _right_panel_style_normal.duplicate() as StyleBoxFlat
    if in_settlement:
        dup.bg_color.a = 0.0
        dup.border_color.a = 0.35
        _right_panel.add_theme_stylebox_override("panel", dup)
    else:
        _right_panel.add_theme_stylebox_override("panel", _right_panel_style_normal.duplicate())


func _on_settlement_claim() -> void:
    var already_claimed: bool = _settlement_claimed
    _settlement_claimed = true
    var gained: int = 0
    var is_practice: bool = _practice_match_active or (
        _controller != null and _controller.is_practice_mode()
    )
    var deposited_items: int = 0
    if not already_claimed and _controller:
        if is_practice:
            _controller.claim_settlement_rewards()
        else:
            gained = _controller.claim_settlement_rewards()
            deposited_items = _deposit_won_loot_to_player()
            _persist_portfolio_from_match()
            var portfolio: Node = get_node_or_null("/root/PlayerPortfolio")
            if portfolio:
                portfolio.record_match_completed()
            _record_leaderboard_match()
    if not already_claimed:
        if is_practice:
            _show_toast("练习局已结算（未扣除门票、战利品不入仓库）")
        else:
            _show_settlement_claim_toast(gained, deposited_items)
    if _settlement_overlay:
        _settlement_overlay.hide()
    _exit_settlement_ui()
    if _bid_area:
        _bid_area.visible = false
    _apply_restart_button_placement(RestartBtnPlacement.SETTLEMENT_BOTTOM)
    _refresh_top_silver()
    _refresh_player_cards(-1, _controller.get_round_index() if _controller else 5, false)


func _record_leaderboard_match() -> void:
    if _practice_match_active or (_controller and _controller.is_practice_mode()):
        return
    var lb: Node = get_node_or_null("/root/PlayerLeaderboard")
    if lb == null or _controller == null or _last_settlement_result == null:
        return
    var result = _last_settlement_result
    for p in _controller.get_players():
        if not p.is_human:
            continue
        var seat: int = p.seat_index
        var human_won: bool = seat == int(result.winner_seat)
        var profit_delta: int = 0
        if human_won:
            profit_delta = int(result.profit_winner)
        elif seat >= 0 and seat < result.player_deltas.size():
            profit_delta = int(result.player_deltas[seat])
        lb.record_match(human_won, profit_delta, int(result.winning_bid))
        return


func _refresh_top_silver() -> void:
    if not _controller:
        return
    for p in _controller.get_players():
        if p.is_human:
            _top_silver.text = _format_comma(p.silver)
            return


func _on_match_settled(result) -> void:
    _set_bid_controls_enabled(false)
    _on_log("结算完成 成交 %s 利润 %s" % [
        MatchControllerScript._format_silver(result.winning_bid),
        MatchControllerScript._format_silver(result.profit_winner),
    ])
    _apply_restart_button_placement(RestartBtnPlacement.SETTLEMENT_BOTTOM)


func _on_match_forfeit_changed(forfeited: bool) -> void:
    _forfeited = forfeited
    if _is_settlement_active() or _is_match_ended_phase():
        _apply_restart_button_placement(RestartBtnPlacement.SETTLEMENT_BOTTOM)
    elif _forfeited:
        _apply_restart_button_placement(RestartBtnPlacement.BID_ROW)
    else:
        _apply_restart_button_placement(RestartBtnPlacement.HIDDEN)
    _update_bid_controls_state()


func _on_player_bid_result(ok: bool, reason: String) -> void:
    if ok and reason.contains("等待"):
        _human_locked_this_round = true
        _update_bid_controls_state()
    if not ok and not reason.is_empty():
        if _is_insufficient_funds_reason(reason):
            _show_toast("金币不足，无法出价")
        else:
            _on_log("[主角] " + reason)
    elif ok and not reason.is_empty() and not reason.contains("弃权"):
        _bid_status.text = reason


func _is_insufficient_funds_reason(reason: String) -> bool:
    return reason == "金币不足，无法出价" or reason.contains("金币不足") or reason.contains("银币不足")


func _show_settlement_claim_toast(silver_gained: int, deposited_items: int) -> void:
    var parts: PackedStringArray = []
    if silver_gained > 0:
        parts.append("%s 金币已存入仓库" % _format_comma(silver_gained))
    if deposited_items > 0:
        parts.append("%d 件藏品已存入仓库" % deposited_items)
    if parts.is_empty():
        return
    var duration: float = 2.8 if parts.size() > 1 else 2.2
    _show_toast("；".join(parts), duration)


func _show_toast(message: String, duration_sec: float = 2.2) -> void:
    if _toast:
        _toast.show_message(message, duration_sec)


func _on_log(text: String) -> void:
    _log.append_text(text + "\n")


func _resolve_leader_seat_for_ui() -> int:
    if _controller == null:
        return -1
    var phase: int = _controller.get_phase()
    if phase == GameConstants.MatchPhase.INFO:
        return -1
    var board = _controller.get_board()
    if board == null or board.current_highest_bid <= 0:
        return -1
    return board.current_leader_seat


func _sync_player_sidebar() -> void:
    if not _controller or _players_list == null:
        return
    if _left_panel:
        _left_panel.visible = true
    _players_list.visible = true
    if _controller.get_players().is_empty():
        return
    if _seat_cards.is_empty():
        _rebuild_player_cards()
        return
    _refresh_player_cards(
        _resolve_leader_seat_for_ui(),
        _controller.get_round_index(),
        _hide_current_round_bids(),
    )


func _rebuild_player_cards() -> void:
    _clear_player_cards()
    if not _controller:
        return
    var leader: int = _resolve_leader_seat_for_ui()
    var human_seat: int = _controller.get_human_seat()
    var current_round: int = _controller.get_round_index()
    var hide_current: bool = _hide_current_round_bids()
    for p in _controller.get_players():
        var card := PlayerSeatCardScript.new()
        card.update_from_player(
            p,
            leader,
            current_round,
            hide_current,
            p.seat_index == human_seat,
            true,
        )
        _players_list.add_child(card)
        _seat_cards.append(card)


func _refresh_player_cards(
    leader_seat: int,
    current_round: int,
    hide_current: bool,
) -> void:
    if _seat_cards.is_empty():
        _rebuild_player_cards()
        return
    var players: Array = _controller.get_players()
    var human_seat: int = _controller.get_human_seat()
    for i in mini(_seat_cards.size(), players.size()):
        var p = players[i]
        _seat_cards[i].update_from_player(
            p,
            leader_seat,
            current_round,
            hide_current,
            p.seat_index == human_seat,
            true,
        )


func _clear_player_cards() -> void:
    if _emote_bubble and _emote_bubble.get_parent() is PlayerSeatCard:
        remove_child(_emote_bubble)
        add_child(_emote_bubble)
        _emote_bubble.hide()
    for c in _seat_cards:
        if not is_instance_valid(c):
            continue
        if c.get_parent() == _players_list:
            _players_list.remove_child(c)
        c.free()
    _seat_cards.clear()


func _set_bid_controls_enabled(enabled: bool) -> void:
    if _forfeited:
        enabled = false
    _update_bid_controls_state()


func _update_bid_controls_state() -> void:
    var in_window: bool = false
    if _controller:
        in_window = _controller.get_phase() == GameConstants.MatchPhase.BID_WINDOW
    var can_act: bool = in_window and not _forfeited and not _human_locked_this_round
    _raise_btn.disabled = not can_act
    _pass_btn.disabled = not can_act
    _bid_input.editable = can_act
    if _bid_numpad:
        _bid_numpad.set_interactive(can_act)
    if _forfeited:
        _forfeit_btn.visible = false
    else:
        _forfeit_btn.visible = _bid_area != null and _bid_area.visible
        _forfeit_btn.disabled = not in_window


func _on_bid_input_submitted(_text: String) -> void:
    _submit_bid_from_input()


func _submit_bid_from_input() -> void:
    if not _controller:
        return
    var amount: int = -1
    if _bid_numpad:
        amount = _bid_numpad.get_amount_value()
    else:
        amount = _parse_bid_input(_bid_input.text)
    if amount < 0:
        _on_log("[主角] 请输入有效出价金额")
        return
    _controller.player_submit_bid(amount)


func _parse_bid_input(text: String) -> int:
    var cleaned: String = text.strip_edges().replace(",", "").replace(" ", "")
    if cleaned.is_empty():
        return -1
    if not cleaned.is_valid_int():
        return -1
    return int(cleaned)


func _on_pass_pressed() -> void:
    if _controller:
        _controller.player_pass_round()
        _human_locked_this_round = true
        _update_bid_controls_state()


func _on_forfeit_pressed() -> void:
    if _controller:
        _controller.player_forfeit_match()
        _human_locked_this_round = true
        _set_bid_controls_enabled(false)


func _on_item_tool_pressed() -> void:
    _on_open_encyclopedia()


func _on_restart_pressed() -> void:
    if not _controller:
        return
    if not _settlement_claimed and _is_match_ended_phase():
        _controller.claim_settlement_rewards()
        _deposit_won_loot_to_player()
        _persist_portfolio_from_match()
        _settlement_claimed = true
    if _settlement_overlay:
        _settlement_overlay.hide()
    _exit_settlement_ui()
    _log.clear()
    _clear_player_cards()
    _forfeited = false
    _human_locked_this_round = false
    _apply_restart_button_placement(RestartBtnPlacement.HIDDEN)
    if _encyclopedia:
        _encyclopedia.hide()
    if _cinematic_overlay:
        _cinematic_overlay.hide()
    if _matchmaking:
        _matchmaking.hide()
    if _practice_match_active:
        _finish_room_practice_session()
        _show_lobby()
        return
    _controller.restart_match()
    _controller.set_practice_mode(false)
    _hide_match_layout()
    if _bid_area:
        _bid_area.visible = false
    if _ai_practice_flow_active:
        _show_map_selection(true, "AI练习")
    else:
        _show_map_selection(false)


func _finish_room_practice_session() -> void:
    _practice_match_active = false
    _room_flow_active = false
    _ai_practice_flow_active = false
    var net: Node = get_node_or_null("/root/RoomNetwork")
    if net and net.is_in_room():
        net.leave_room()
    if _room_battle_ui:
        _room_battle_ui.hide()
    if _controller:
        _controller.set_practice_mode(false)
        _controller.clear_room_network()
        _controller.restart_match()


func _apply_restart_button_placement(placement: int) -> void:
    if _restart_btn == null:
        return
    _restart_placement = placement
    match placement:
        RestartBtnPlacement.BID_ROW:
            _ensure_restart_in_bid_row()
            _restart_btn.visible = true
            if _restart_canvas_layer:
                _restart_canvas_layer.visible = false
            if _forfeit_btn:
                _forfeit_btn.visible = false
        RestartBtnPlacement.SETTLEMENT_BOTTOM:
            _ensure_restart_in_bottom_host()
            _restart_btn.visible = true
            _restart_btn.mouse_filter = Control.MOUSE_FILTER_STOP
            if _restart_canvas_layer:
                _restart_canvas_layer.visible = true
            if _bid_area:
                _bid_area.visible = false
            if _forfeit_btn:
                _forfeit_btn.visible = false
        _:
            _restart_btn.visible = false
            if _restart_canvas_layer:
                _restart_canvas_layer.visible = false
            if _forfeit_btn and _bid_area and _bid_area.visible and not _forfeited:
                _forfeit_btn.visible = true
    _style_restart_button()


func _reparent_restart_btn(new_parent: Node) -> void:
    if _restart_btn == null or new_parent == null:
        return
    var old_parent: Node = _restart_btn.get_parent()
    if old_parent == new_parent:
        return
    if old_parent:
        old_parent.remove_child(_restart_btn)
    new_parent.add_child(_restart_btn)


func _ensure_restart_in_bid_row() -> void:
    if _restart_btn == null or _bid_buttons_row == null:
        return
    if _restart_btn.get_parent() == _bid_buttons_row:
        return
    _reparent_restart_btn(_bid_buttons_row)
    var forfeit_idx: int = _bid_buttons_row.get_child_count() - 1
    if _forfeit_btn and _forfeit_btn.get_parent() == _bid_buttons_row:
        forfeit_idx = _forfeit_btn.get_index() + 1
    _bid_buttons_row.move_child(_restart_btn, forfeit_idx)
    _restart_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _restart_btn.size_flags_stretch_ratio = 0.42
    _restart_btn.custom_minimum_size = Vector2(0, 52)


func _ensure_restart_in_bottom_host() -> void:
    if _restart_btn == null:
        return
    _setup_restart_button_anchor()
    if _restart_btn_host == null:
        return
    _reparent_restart_btn(_restart_btn_host)
    _restart_btn.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
    _restart_btn.offset_left = -100.0
    _restart_btn.offset_right = 100.0
    _restart_btn.offset_top = -80.0
    _restart_btn.offset_bottom = -28.0
    _restart_btn.custom_minimum_size = UiButtonStyleScript.ACTION_BTN_SIZE
    _restart_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    _restart_btn.z_index = 10
    _style_restart_button()


func _style_restart_button() -> void:
    if _restart_btn == null:
        return
    var white: Color = UiButtonStyleScript.ACTION_BTN_TEXT_COLOR
    var h: int = int(UiButtonStyleScript.ACTION_BTN_SIZE.y)
    match _restart_placement:
        RestartBtnPlacement.SETTLEMENT_BOTTOM:
            _restart_btn.custom_minimum_size = UiButtonStyleScript.ACTION_BTN_SIZE
            UiButtonStyleScript.apply_centered_action(
                _restart_btn, white, UiButtonStyleScript.ACTION_BTN_FONT_SIZE, h
            )
        RestartBtnPlacement.BID_ROW:
            UiButtonStyleScript.apply_centered_action(
                _restart_btn, white, UiButtonStyleScript.ACTION_BTN_FONT_SIZE, h
            )
        _:
            pass


func _style_bid_action_buttons() -> void:
    if _raise_btn:
        UiButtonStyleScript.apply_centered_action(_raise_btn, Color(1, 1, 1, 1), 20, 52)
        UiButtonStyleScript.refresh_centered(_raise_btn)
    if _forfeit_btn:
        UiButtonStyleScript.apply_danger(_forfeit_btn, 16)
        UiButtonStyleScript.refresh_centered(_forfeit_btn)
    if _bid_status:
        _bid_status.add_theme_font_size_override("font_size", 15)
    if _pass_btn:
        UiButtonStyleScript.apply(_pass_btn, Color(0.9, 0.88, 0.92))
    if _item_btn:
        UiButtonStyleScript.apply(_item_btn)
    if _emote_btn:
        UiButtonStyleScript.apply(_emote_btn, Color(0.9, 0.92, 0.98), 14)
        UiButtonStyleScript.refresh_centered(_emote_btn)
    _style_restart_button()


static func _format_comma(amount: int) -> String:
    var s: String = str(amount)
    var out: String = ""
    var n: int = s.length()
    for i in n:
        if i > 0 and (n - i) % 3 == 0:
            out += ","
        out += s[i]
    return out

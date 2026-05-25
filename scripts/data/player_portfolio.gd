extends Node
## 玩家总资产与 K 线展示（持久化到 user://）
## 初始为 0→200 万缓增的固定模拟曲线；每完成一局在尾部追加上下波动

const SAVE_PATH := "user://player_portfolio.json"
const CHART_POINT_COUNT: int = 48
const BASELINE_NODE_COUNT: int = 36
const MATCH_WIGGLE_STEPS: int = 6
const CHART_SERIES_MAX: int = 72

var total_assets: int = GameConstants.STARTING_SILVER
var day_open_assets: int = GameConstants.STARTING_SILVER
var yesterday_close_assets: int = GameConstants.STARTING_SILVER
var day_key: String = ""
var intraday_samples: Array[int] = []
var matches_completed: int = 0
## 折线原始采样（含基线 + 每局波动延伸）
var chart_series: Array[int] = []


func _ready() -> void:
    load_data()
    _ensure_day_rollover()
    _ensure_chart_series()


func _exit_tree() -> void:
    save_data()


func sync_total(amount: int) -> void:
    _ensure_day_rollover()
    total_assets = maxi(0, amount)
    _append_sample(total_assets)
    if not chart_series.is_empty():
        chart_series[chart_series.size() - 1] = total_assets
    save_data()


func spend_silver(amount: int) -> bool:
    if amount <= 0:
        return true
    if total_assets < amount:
        return false
    sync_total(total_assets - amount)
    return true


func add_silver(amount: int) -> void:
    if amount <= 0:
        return
    sync_total(total_assets + amount)


func get_today_change() -> int:
    return total_assets - day_open_assets


func get_today_change_pct() -> float:
    if day_open_assets <= 0:
        return 0.0
    return float(get_today_change()) / float(day_open_assets) * 100.0


func get_yesterday_close_assets() -> int:
    return maxi(0, yesterday_close_assets)


func is_today_up() -> bool:
    return get_today_change() >= 0


func has_played_match() -> bool:
    return matches_completed > 0


func record_match_completed() -> void:
    matches_completed += 1
    _extend_chart_after_match(total_assets)
    save_data()


func get_chart_values() -> PackedFloat32Array:
    _ensure_chart_series()
    var raw: PackedFloat32Array = PackedFloat32Array()
    for v in chart_series:
        raw.append(float(v))
    return _resample_line(raw, CHART_POINT_COUNT)


func is_chart_overall_up() -> bool:
    var values: PackedFloat32Array = get_chart_values()
    if values.size() < 2:
        return true
    return values[values.size() - 1] >= values[0]


func load_data() -> void:
    if not FileAccess.file_exists(SAVE_PATH):
        _reset_day(GameConstants.STARTING_SILVER)
        _init_baseline_growth_curve()
        return
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
    if typeof(parsed) != TYPE_DICTIONARY:
        _reset_day(GameConstants.STARTING_SILVER)
        _init_baseline_growth_curve()
        return
    total_assets = int(parsed.get("total_assets", GameConstants.STARTING_SILVER))
    day_open_assets = int(parsed.get("day_open_assets", total_assets))
    yesterday_close_assets = int(
        parsed.get("yesterday_close_assets", day_open_assets),
    )
    day_key = str(parsed.get("day_key", ""))
    matches_completed = int(parsed.get("matches_completed", 0))
    intraday_samples.clear()
    for v in parsed.get("intraday_samples", []):
        intraday_samples.append(int(v))
    chart_series.clear()
    for v in parsed.get("chart_series", []):
        chart_series.append(int(v))
    _ensure_day_rollover()
    _ensure_chart_series()


func save_data() -> void:
    var data: Dictionary = {
        "total_assets": total_assets,
        "day_open_assets": day_open_assets,
        "yesterday_close_assets": yesterday_close_assets,
        "day_key": day_key,
        "intraday_samples": intraday_samples.duplicate(),
        "matches_completed": matches_completed,
        "chart_series": chart_series.duplicate(),
    }
    var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    if file:
        file.store_string(JSON.stringify(data))
    else:
        push_error("PlayerPortfolio: 无法写入 %s (err=%d)" % [SAVE_PATH, FileAccess.get_open_error()])


func _ensure_day_rollover() -> void:
    var today: String = _today_key()
    if day_key == today:
        return
    _reset_day(total_assets)


func _reset_day(open_amount: int) -> void:
    if not day_key.is_empty():
        yesterday_close_assets = maxi(0, total_assets)
    else:
        yesterday_close_assets = maxi(0, open_amount)
    day_key = _today_key()
    day_open_assets = maxi(0, open_amount)
    total_assets = day_open_assets
    intraday_samples.clear()
    intraday_samples.append(total_assets)


func _ensure_chart_series() -> void:
    if not chart_series.is_empty():
        return
    _init_baseline_growth_curve()


func _init_baseline_growth_curve() -> void:
    chart_series.clear()
    var target: int = GameConstants.STARTING_SILVER
    var n: int = BASELINE_NODE_COUNT
    for i in n:
        var t: float = float(i) / float(n - 1) if n > 1 else 1.0
        # 缓步爬升：前期慢、后期略快，整体平滑无尖刺
        var ease: float = pow(t, 0.72)
        var micro: float = sin(t * TAU * 1.15) * float(target) * 0.012 * (1.0 - t * 0.6)
        var value: int = clampi(int(ease * float(target) + micro), 0, target)
        chart_series.append(value)
    if chart_series.is_empty() or chart_series[chart_series.size() - 1] != target:
        chart_series.append(target)


func _extend_chart_after_match(new_total: int) -> void:
    _ensure_chart_series()
    var last_val: int = int(chart_series[chart_series.size() - 1])
    var end_total: int = maxi(0, new_total)
    if last_val == end_total and matches_completed > 1:
        # 资产未变也加一点视觉波动
        var flat_rng := RandomNumberGenerator.new()
        flat_rng.seed = matches_completed * 104729
        var bump: int = flat_rng.randi_range(-60000, 60000)
        chart_series.append(maxi(0, end_total + bump))
        chart_series.append(end_total)
        _trim_chart_series()
        return
    var rng := RandomNumberGenerator.new()
    rng.seed = matches_completed * 104729 + end_total
    var span: int = maxi(1, absi(end_total - last_val))
    var swing: float = float(span) * 0.14 + float(GameConstants.STARTING_SILVER) * 0.018
    for step in range(1, MATCH_WIGGLE_STEPS + 1):
        var t: float = float(step) / float(MATCH_WIGGLE_STEPS)
        var base: float = lerpf(float(last_val), float(end_total), t)
        var wave: float = sin(t * PI * 2.2 + float(matches_completed) * 0.9) * swing * (1.0 - t * 0.35)
        var noise: float = rng.randf_range(-swing * 0.4, swing * 0.4)
        var point: int = clampi(int(base + wave + noise), 0, maxi(end_total, last_val) + span)
        chart_series.append(point)
    if chart_series[chart_series.size() - 1] != end_total:
        chart_series.append(end_total)
    _trim_chart_series()


func _trim_chart_series() -> void:
    if chart_series.size() <= CHART_SERIES_MAX:
        return
    var start: int = chart_series.size() - CHART_SERIES_MAX
    chart_series = chart_series.slice(start)


func _append_sample(value: int) -> void:
    var v: int = maxi(0, value)
    if intraday_samples.is_empty() or intraday_samples[intraday_samples.size() - 1] != v:
        intraday_samples.append(v)


func _today_key() -> String:
    var dt: Dictionary = Time.get_datetime_dict_from_system()
    return "%04d-%02d-%02d" % [dt.year, dt.month, dt.day]


static func _resample_line(source: PackedFloat32Array, count: int) -> PackedFloat32Array:
    var out: PackedFloat32Array = PackedFloat32Array()
    if source.is_empty() or count < 2:
        return out
    if source.size() == 1:
        out.append(source[0])
        out.append(source[0])
        return out
    for i in count:
        var t: float = float(i) / float(count - 1)
        var idx_f: float = t * float(source.size() - 1)
        var idx0: int = int(floor(idx_f))
        var idx1: int = mini(idx0 + 1, source.size() - 1)
        var frac: float = idx_f - float(idx0)
        out.append(lerpf(source[idx0], source[idx1], frac))
    return out

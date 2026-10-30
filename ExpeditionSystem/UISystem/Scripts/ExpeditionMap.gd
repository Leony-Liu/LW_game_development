@tool
## 只绘制拥有者提供的已发现房间和中心标记。
## 编辑器样例与运行时快照分离，不读取或修改 World。
extends Control

@export_group("Map Colors")
@export var explored_room_color: Color = Color.WHITE:
	set(value):
		explored_room_color = value
		queue_redraw()
@export var player_marker_color: Color = Color.GREEN:
	set(value):
		player_marker_color = value
		queue_redraw()
@export var initial_room_marker_color: Color = Color.GOLD:
	set(value):
		initial_room_marker_color = value
		queue_redraw()

@export_group("Map Layout")
@export_range(16.0, 160.0, 1.0) var preferred_room_size: float = 72.0:
	set(value):
		preferred_room_size = value
		queue_redraw()
@export_range(0.0, 80.0, 1.0) var room_gap: float = 18.0:
	set(value):
		room_gap = value
		queue_redraw()
@export_range(0.0, 160.0, 1.0) var map_padding: float = 48.0:
	set(value):
		map_padding = value
		queue_redraw()
@export_range(1.0, 6.0, 0.5) var outline_width: float = 2.0:
	set(value):
		outline_width = value
		queue_redraw()

var _room_coords: Array[Vector2] = []
var _player_coords: Vector2 = Vector2.INF
var _initial_coords: Vector2 = Vector2.INF
var _room_spacing: float = 1.0

# 独立编辑时保留场景可见，游戏中由 ExpeditionManager 显式打开。
func _ready() -> void:
	resized.connect(queue_redraw)
	if not Engine.is_editor_hint():
		hide()

# 仅缓存展示快照；发现与占用的权威记录始终由 World 持有。
func display_map(snapshot: Dictionary) -> void:
	_room_coords.assign(snapshot.get("explored_room_coords", []))
	_player_coords = snapshot.get("player_room_coords", Vector2.INF)
	_initial_coords = snapshot.get("initial_room_coords", Vector2.INF)
	_room_spacing = snapshot.get("room_spacing", 1.0)
	queue_redraw()

# 编辑器预览使用独立单位样例，绝不写入运行时房间快照。
func _draw() -> void:
	if Engine.is_editor_hint():
		var preview: Array[Vector2] = [Vector2.ZERO, Vector2.RIGHT, Vector2.UP]
		_draw_discovered_map(preview, Vector2.ZERO, Vector2.ZERO, 1.0)
		return
	_draw_discovered_map(_room_coords, _player_coords, _initial_coords, _room_spacing)

# 按 X/Z 原坐标投影，发现范围统一居中并等比缩放，不画连接或未知占位。
func _draw_discovered_map(coords: Array[Vector2], player_coords: Vector2, initial_coords: Vector2, spacing: float) -> void:
	if coords.is_empty() or spacing <= 0.0:
		return
	var layout := _get_map_layout(coords, spacing)
	if layout.is_empty():
		return
	var square_size: float = layout["square_size"]
	var line_width: float = outline_width * layout["scale"]
	for coord in coords:
		var center: Vector2 = size * 0.5 + (coord / spacing - layout["grid_center"]) * layout["pitch"]
		draw_rect(Rect2(center - Vector2.ONE * square_size * 0.5, Vector2.ONE * square_size), explored_room_color, false, line_width, true)
		# 菱形先画且比圆更大，重叠时仍露出四个角。
		if coord == initial_coords:
			var radius := square_size * 0.24
			draw_colored_polygon(PackedVector2Array([
				center + Vector2(0.0, -radius), center + Vector2(radius, 0.0),
				center + Vector2(0.0, radius), center + Vector2(-radius, 0.0),
			]), initial_room_marker_color)
		if coord == player_coords:
			draw_circle(center, square_size * 0.12, player_marker_color, true, -1.0, true)

# 仅根据已发现坐标求绘制范围，统一缩放方形、间距和标记。
func _get_map_layout(coords: Array[Vector2], spacing: float) -> Dictionary:
	var available := size - Vector2.ONE * map_padding * 2.0
	if coords.is_empty() or available.x <= 0.0 or available.y <= 0.0:
		return {}
	var minimum := coords[0] / spacing
	var maximum := minimum
	for coord in coords:
		minimum = minimum.min(coord / spacing)
		maximum = maximum.max(coord / spacing)
	var pitch := preferred_room_size + room_gap
	var extent := (maximum - minimum) * pitch + Vector2.ONE * (preferred_room_size + outline_width)
	var fit_scale := minf(1.0, minf(available.x / extent.x, available.y / extent.y))
	return {
		"grid_center": (minimum + maximum) * 0.5,
		"pitch": pitch * fit_scale,
		"square_size": preferred_room_size * fit_scale,
		"scale": fit_scale,
	}

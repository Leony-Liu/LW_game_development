class_name DebugFreeCamera
extends Camera3D

@export var move_speed: float = 15.0
@export var boost_factor: float = 2.5
@export var mouse_sensitivity: float = 0.003

var _is_rmb_down: bool = false
var _rot_x: float = 0.0
var _rot_y: float = 0.0

func _ready() -> void:
	_rot_x = rotation.x
	_rot_y = rotation.y

func _unhandled_input(event: InputEvent) -> void:
	# 按住鼠标右键时捕获鼠标并旋转视角
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_is_rmb_down = event.pressed
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if _is_rmb_down else Input.MOUSE_MODE_VISIBLE

	# 鼠标移动控制视角偏航与俯仰
	if _is_rmb_down and event is InputEventMouseMotion:
		_rot_y -= event.relative.x * mouse_sensitivity
		_rot_x -= event.relative.y * mouse_sensitivity
		_rot_x = clamp(_rot_x, -deg_to_rad(89.0), deg_to_rad(89.0))
		
		rotation = Vector3(_rot_x, _rot_y, 0.0)

func _process(delta: float) -> void:
	if not current: return

	# 收集移动方向向量
	var input_vec = Vector3.ZERO
	if Input.is_key_pressed(KEY_W): input_vec -= transform.basis.z
	if Input.is_key_pressed(KEY_S): input_vec += transform.basis.z
	if Input.is_key_pressed(KEY_A): input_vec -= transform.basis.x
	if Input.is_key_pressed(KEY_D): input_vec += transform.basis.x
	if Input.is_key_pressed(KEY_E): input_vec += Vector3.UP
	if Input.is_key_pressed(KEY_Q): input_vec -= Vector3.UP

	if input_vec != Vector3.ZERO:
		input_vec = input_vec.normalized()
		var speed = move_speed * (boost_factor if Input.is_key_pressed(KEY_SHIFT) else 1.0)
		position += input_vec * speed * delta

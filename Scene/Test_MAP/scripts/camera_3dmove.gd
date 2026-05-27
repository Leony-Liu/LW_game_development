extends Camera3D

# --- 可调节参数 ---
@export var mouse_sensitivity: float = 0.0015 # 鼠标灵敏度
@export var move_speed: float = 3.0          # 基础移动速度
@export var boost_multiplier: float = 3.0    # 加速倍率 (按住 Shift 时)

var pitch: float = 0.0
var yaw: float = 0.0

func _ready():
	# 游戏开始时，隐藏并捕获鼠标指针
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	# 根据摄像机当前的初始朝向同步变量
	yaw = rotation.y
	pitch = rotation.x

func _input(event):
	# 按下 ESC 键释放/捕获鼠标 (重要！否则你的鼠标退不出来)
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	# 处理鼠标移动视角
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * mouse_sensitivity
		pitch -= event.relative.y * mouse_sensitivity
		# 限制上下低头抬头的角度 (防止画面翻转)
		pitch = clamp(pitch, -PI/2, PI/2) 
		
		rotation.y = yaw
		rotation.x = pitch

func _process(delta):
	# 如果鼠标没被捕获，就暂停移动操作
	if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
		return

	var velocity = Vector3.ZERO
	var current_speed = move_speed

	# 按住 Shift 键加速
	if Input.is_physical_key_pressed(KEY_SHIFT):
		current_speed *= boost_multiplier

	# 获取摄像机当前的局部方向
	var forward = -transform.basis.z
	var right = transform.basis.x
	var up = transform.basis.y

	# WASD 水平移动
	if Input.is_physical_key_pressed(KEY_W):
		velocity += forward
	if Input.is_physical_key_pressed(KEY_S):
		velocity -= forward
	if Input.is_physical_key_pressed(KEY_A):
		velocity -= right
	if Input.is_physical_key_pressed(KEY_D):
		velocity += right
		
	# Q 和 E 垂直升降
	if Input.is_physical_key_pressed(KEY_E):
		velocity += up
	if Input.is_physical_key_pressed(KEY_Q):
		velocity -= up

	# 归一化以防止斜向移动过快，并应用位移
	if velocity.length() > 0:
		velocity = velocity.normalized()
		position += velocity * current_speed * delta

#受击盒子
#角色受击时触发的攻击逻辑
class_name Hurtbox
extends Area3D

signal hurt(hitbox)

func _init() -> void:
	area_entered.connect(_on_area_entered)

func _on_area_entered(hit: HitBox) -> void:
	print("[Hurt] %s => %s" % [hit.owner.name, owner.name] )
	hurt.emit(hit)
	hit.hit.emit(self)
	pass

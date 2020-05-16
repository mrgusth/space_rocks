extends RigidBody2D

export (int) var engine_power
export (int) var spin_power
export (PackedScene) var Bullet
export (float) var fire_rate
export (int) var max_shield
export (float) var shield_regen


signal dead
signal shoot
signal lives_changed
signal shield_changed

var shield = 0 setget set_shield
var lives = 0 setget set_lives
var can_shoot = true
var thrust = Vector2()
var rotation_dir = 0
enum{INIT, ALIVE, INVULNERABLE, DEAD} # 0, 1, 2, 3 assigned respectively
var state = null

var screensize = Vector2()

func set_shield(value):
	if value > max_shield:
		value = max_shield
	shield = value
	emit_signal("shield_changed", shield/max_shield)
	if shield <= 0:
		self.lives -= 1

func set_lives(value):
	self.shield = max_shield
	lives = value
	emit_signal("lives_changed", lives)

func start():
	$Sprite.show()
	self.shield = max_shield
	
	self.lives = 3
	change_state(ALIVE)

# Called when the node enters the scene tree for the first time.
func _ready():
	change_state(ALIVE) 
	screensize = get_viewport().get_visible_rect().size
	$GunTimer.wait_time = fire_rate

func change_state(new_state):
	match new_state:
		INIT:
			$CollisionShape2D.disabled = true
			$Sprite.modulate.a = 0.5
		ALIVE:
			$CollisionShape2D.disabled = false
			$Sprite.modulate.a = 1.0
		INVULNERABLE:
			$CollisionShape2D.disabled = true
			$Sprite.modulate.a = 0.5
			$InvulnerabilityTimer.start()
		DEAD:
			$CollisionShape2D.disabled = true
			$Sprite.hide()
			linear_velocity = Vector2()
			$EngineSound.stop()
			emit_signal("dead")
	state = new_state
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	self.shield += shield_regen * delta 
	get_input()
	
func get_input():
	thrust = Vector2()
	$Exhaust.emitting = false
	if state in [DEAD, INIT]:
		return
	if Input.is_action_pressed("thrust"):
		thrust = Vector2(engine_power, 0)
		$Exhaust.emitting = true
		if not $EngineSound.playing:
			$EngineSound.play()
		else:
			$EngineSound.stop()
	rotation_dir = 0
	if Input.is_action_pressed("rotate_right"):
		rotation_dir += 1
	if Input.is_action_pressed("rotate_left"):
		rotation_dir -= 1
	if Input.is_action_pressed("shoot") and can_shoot:
		shoot()
		$LaserSound.play()

func _integrate_forces(physics_state):
	set_applied_force(thrust.rotated(rotation))
	set_applied_torque(spin_power * rotation_dir)
	var xform = physics_state.get_transform()
	if xform.origin.x > screensize.x:
		xform.origin.x = 0
	if xform.origin.x < 0:
		xform.origin.x = screensize.x
	if xform.origin.y > screensize.y:
		xform.origin.y = 0
	if xform.origin.y < 0:
		xform.origin.y = screensize.y
	physics_state.set_transform(xform) 

func shoot():
	if state == INVULNERABLE:
		return
	emit_signal("shoot", Bullet, $Muzzle.global_position, rotation)
	can_shoot = false
	$GunTimer.start()
	#$LaserSound.play()


func _on_GunTimer_timeout():
	can_shoot = true


func _on_InvulnerabilityTimer_timeout():
	change_state(ALIVE)


func _on_AnimationPlayer_animation_finished(anim_name):
	$Explosion.hide()


func _on_Player_body_entered(body):
	if body.is_in_group('rocks'):
		body.explode()
		$Explosion.show()
		$Explosion/AnimationPlayer.play('explosion')
		self.shield -= body.size * 25
		if lives <= 0:
			change_state(DEAD)
		else: 
			change_state(INVULNERABLE)
		

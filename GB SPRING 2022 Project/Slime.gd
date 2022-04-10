extends KinematicBody2D

enum State {GROUND, AIR}
var state = State.GROUND


# Declare member variables here. Examples:
# var a = 2
# var b = "text"

# walk properties
export var gravity = 5
export var jump_speed = 200

export var walk_speed = 1000
export var ground_deceleration = 10000
export var ground_acceleration = 5000
export var ground_friction = 8000
export var air_deceleration = 10000
export var air_acceleration = 5000
export var air_friction = 8000
export var min_cancelable_jump_scalar = 0.1

const JUMP_BUFFER_FRAMES = 12
const VELOCITY_EPSILON = 0.1

var jump_buffer_count = 0

var velocity = Vector2(0, 0)
var jump_pressed = false
var jump_ended = false
var move_direction = 0
var x_stretch = 1
var y_stretch = 1


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.
	

func _input(event):
	if event.is_action_pressed("jump"):
		jump_buffer_count = JUMP_BUFFER_FRAMES


func state_ground(dt):
	jump_ended = true
	if not is_on_floor():
		state = State.AIR
		return
		
	if jump_buffer_count > 0:
		velocity = player_jump(velocity)
		state = State.AIR
		return
		
	x_stretch = lerp(x_stretch, 1, 0.08)
	y_stretch = lerp(y_stretch, 1, 0.08)
	
	velocity = horizontal_move(
		velocity, 
		move_direction, 
		ground_acceleration, 
		ground_deceleration, 
		ground_friction,
		dt
	)


func horizontal_move(
		current_velocity, 
		direction, 
		acceleration, 
		braking_deceleration,
		friction_deceleration,
		dt
	):
	if ( # if moving in opposite direction of velocity...
		direction == -sign(current_velocity.x) and 
		abs(current_velocity.x) > VELOCITY_EPSILON
	):
		# apply braking
		current_velocity.x += direction * braking_deceleration * dt
	elif direction != 0: # if moving...
		# apply speed-up acceleration
		current_velocity.x += direction * acceleration * dt
		current_velocity.x = clamp(current_velocity.x, -walk_speed, walk_speed)
	else:
		# apply friction
		current_velocity.x = move_toward(
			current_velocity.x, 0, friction_deceleration * dt
		)
	return current_velocity


func state_air(dt):
	if is_on_floor():
		state = State.GROUND
		velocity.y = 0
		on_land()
		return
	# euler integration (good enough :sunglasses:)
	velocity.y += gravity * dt
	x_stretch = lerp(x_stretch, 1, 0.12)
	y_stretch = lerp(y_stretch, 1, 0.12)
	
	if (
		jump_ended == false
		and not Input.is_action_pressed("jump")
		and velocity.y < jump_speed * min_cancelable_jump_scalar
	):
		jump_ended = true
		# TODO: change how this works. interpolation or curve?
		velocity.y = velocity.y * 0.6
		print("jump cancelled!")
	
	velocity = horizontal_move(
		velocity, 
		move_direction, 
		air_acceleration, 
		air_deceleration, 
		air_friction,
		dt
	)


func player_jump(current_velocity):
	jump_buffer_count = 0
	jump_ended = false
	x_stretch = 0.7
	y_stretch = 1.5
	return Vector2(current_velocity.x, -jump_speed)


func on_land():
	if jump_buffer_count == 0:
		x_stretch = 1.3
		y_stretch = 0.8


func _physics_process(delta):
	var left_input = Input.is_action_pressed("walk_left")
	var right_input = Input.is_action_pressed("walk_right")
	move_direction = int(right_input) - int(left_input)
	
	if state == State.GROUND:
		state_ground(delta)
	elif state == State.AIR:
		state_air(delta)
	
	get_node("Sprite").scale = Vector2(0.17 * x_stretch, 0.17 * y_stretch)
	#var sprite_height = get_node("Sprite").texture.get_height()
	#get_node("Sprite").offset = Vector2(0, 0.5*sprite_height * (1-y_stretch))
	
	move_and_slide(velocity * delta * 1000, Vector2.UP, true)
	jump_buffer_count = max(jump_buffer_count - 1, 0)


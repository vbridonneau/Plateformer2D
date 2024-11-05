extends CharacterBody2D

# Jump related variables
@onready var coyote_timer: Timer = $Timers/CoyoteTimer
@onready var jump_timer:   Timer = $Timers/JumpTimer
@onready var buffer_timer: Timer = $Timers/BufferTimer
const JUMP_VELOCITY:       float = -300.0
const MAX_SPEED_Y:         float = -1.5 * JUMP_VELOCITY
const FRICTION:            float = 0.025 # Friction in the air 
var jump_buffer:           bool  = false
var double_jump:           bool  = false
var lastState:             bool  = false # True if the player was on the floor at the vet last frame
var jumping:               bool  = false # True if the player has jump previously
var coyote:                bool  = false

# Speed control
const ACCELERATION: float = 60/3
const DECELERATION: float = 60/6
const SPEED:        float = 130.0

# Implementing wall sliding and wall jump
@onready var bezier_accel_wall_jump: Node2D = $BezierAccelWallJump
@onready var wall_jump_timer:        Timer  = $Timers/WallJumpTimer
@onready var coyote_wall_timer: Timer = $Timers/CoyoteWallTimer
const WALLJUMP_DECELERACTION:        float  = 30
const PROPULSION_SPEED_X:            float  = 450
const PROPULSION_SPEED_Y:            float  = -450
const NEUTRAL_SPEED_X:               float  = 300
const NEUTRAL_SPEED_Y:               float  = -500
const FRICTION_SLIDING:              float  = 0.2 # Friction on a sliding wall
var wall_jump_direction:             float  = 0
var wall_jumping:                    bool   = false # Is the player wall jumping
var init_speed_x:                    float  = 0
var init_speed_y:                    float  = 0
var coyote_wall:                     bool   = false # Allow some delay for the player to wall jump
var was_on_wall:                     bool   = false # Useful to reable wall jump in the air
# Differentiate neutral wall jump (short wall jump which goes back to the wall) from propulsion wall jump.
var propulsion:                      bool   = false # True if the wall jump is a propulsion

# Allowing dash
@onready var dash_timer: Timer = $Timers/DashTimer
@onready var accel_dash: Node  = $BezierAccelDash
const DASH_DECELATION:   int   = 240
const DIAG_DASH_SPEED:   int   = DASH_SPEED * sqrt(2) / 2
# Dashing is allowed on the flour and in the air only once if the player does not exit the flour dashing
var available_dash:      int   = 1
const DASH_SPEED:        int   = 900
var dashing:             bool  = false

# Animation
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

# Check wether the left or the right wall was collided
func get_sign_which_wall_collided() -> int:
	for i in range(get_slide_collision_count()):
		var collision: KinematicCollision2D = get_slide_collision(i)
		if collision.get_normal().x > 0:
			return -1 # Left
		elif collision.get_normal().x < 0:
			return 1 # Right
	return 0 # No collision detected

# Return true if the character is wall sliding (is on a wall and direction is pressed toward that wall)
func wall_sliding() -> bool:
	# Récupère les directions
	var direction := Input.get_axis("left", "right")
	
	# If the character is falling and its direction is the same as the wall it is next to
	return is_on_wall_only() and velocity.y > 0 and direction == get_sign_which_wall_collided()


func handle_gravity(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		var acceleration = get_gravity() * delta - FRICTION * velocity
		if wall_sliding():
			acceleration *= FRICTION_SLIDING # Reduce the accelaration
		velocity += acceleration
		# Enable coyote
		if lastState and not jumping:
			coyote = true
			coyote_timer.start()
	else:
		# Set the number of possible dash so that dash is only possible
		# from the flour or in the aire only once
		available_dash = 1
		wall_jumping   = false
		double_jump    = false
		jumping        = false

# Set all the properties for a nice wall jump
func wall_jump() -> void:
	propulsion          = Input.get_axis("left", "right") == wall_jump_direction
	print("propulsion" if propulsion else "neutral")
	init_speed_x        = velocity.x
	init_speed_y        = velocity.y
	
# Set all variable to false
func reset_all_jump_variables() -> void:
	jump_buffer = false
	double_jump = false
	coyote_wall = false
	jumping     = false
	coyote      = false

# Handle jump.
func handle_jump() -> void: 
	# Rest wall jump if the caracter land on a wall
	if not was_on_wall and is_on_wall(): wall_jumping = false
	# Allow for coyote wall jump
	if was_on_wall and not is_on_wall():
		coyote_wall = true
		coyote_timer.start()
	# Store the wall jump direction (in case of coyote wall jump)
	if is_on_wall():
		wall_jump_direction = - get_sign_which_wall_collided()
		
	# Check if the jump button is pressed
	if Input.is_action_just_pressed("jump"):
		buffer_timer.start()
		jump_buffer = true
	
	if jump_buffer and not dashing:
		# Jump is allowed if :
		# - The player is on the flour
		# - The player is in coyote (a little bit after exiting the flour)
		if (is_on_floor() or coyote):
			velocity.y  = JUMP_VELOCITY
			reset_all_jump_variables()
			jumping     = true
			jump_timer.start()
		# Check whether wall jump is possible
		elif (is_on_wall_only() and not wall_jumping) or coyote_wall:
			wall_jump()
			wall_jump_timer.start()
			reset_all_jump_variables()
			wall_jumping = true
			animated_sprite.play("saut")
		# Double jump is allowed
		elif jumping and not double_jump and not wall_jumping:
			reset_all_jump_variables()
			double_jump = true
			velocity.y  = JUMP_VELOCITY
			animated_sprite.play("saut")

# Make the speed going toward its limit
func speed_up_bezier(from_x : float, to_x: float, from_y : float, to_y: float, accel : float) -> void:
	velocity.x = lerp(from_x, to_x, accel)
	velocity.y = lerp(from_y, to_y, accel)

func handle_movement(delta: float) -> void:
	 # Get the input direction and handle the movement/deceleration.
	var direction         := Input.get_axis("left", "right")
	var direction_up_down := Input.get_axis("up", "down") # Required only for diagonal dash
	var ask_dash          := Input.is_action_just_pressed("dash")
	if direction or direction_up_down:
		# Setup the dash
		if !dashing and ask_dash and available_dash:
			dash_timer.start()
			dashing        = true
			available_dash = 0
			if direction and not direction_up_down:
				velocity.x = direction * DASH_SPEED
			elif direction_up_down and not direction:
				velocity.y = direction_up_down * DASH_SPEED
			else:
				velocity.x = direction * DIAG_DASH_SPEED
				velocity.y = direction_up_down * DIAG_DASH_SPEED
		# Decelerate the dash
		elif dashing:
			# Count the amount of time since the dash is enabled (make it a ratio)
			var t:            float = dash_timer.time_left/dash_timer.wait_time
			var acceleration: float = accel_dash.acceleration(t)
			var dashing_x:    bool  = false
			var dashing_y:    bool  = false
			if abs(velocity.x) > SPEED:
				dashing_x = true
				velocity.x = lerp(direction * DASH_SPEED,
					direction * SPEED,
					acceleration)
			if abs(velocity.y) > SPEED:
				dashing_y = true
				velocity.y = lerp(direction_up_down * DASH_SPEED,
					direction_up_down * SPEED,
					acceleration)
			dashing = dashing_x or dashing_y
		# Normal movement (Speed up toward the maximum speed)
		else:
			if wall_jumping:
				var t:                 float = wall_jump_timer.time_left / wall_jump_timer.wait_time
				var accel :            float = bezier_accel_wall_jump.acceleration(t)
				var wall_jump_speed_x: float = PROPULSION_SPEED_X if propulsion else NEUTRAL_SPEED_X
				var wall_jump_speed_y: float = PROPULSION_SPEED_Y if propulsion else NEUTRAL_SPEED_Y
				speed_up_bezier(init_speed_x,
					wall_jump_direction * wall_jump_speed_x,
					init_speed_y,
					wall_jump_speed_y,
					accel)
			else:
				velocity.x = move_toward(velocity.x, direction * SPEED, delta * ACCELERATION * SPEED)	
		# Flip the animation so that the oritentation is the same as the direction of the player
		animated_sprite.flip_h = (direction == -1)
	else:
		velocity.x = move_toward(velocity.x, 0, delta * DECELERATION * SPEED)

func _physics_process(delta: float) -> void:
	# Hndling gravity and jumps (include jump, double jump and coyote)
	handle_gravity(delta)
	handle_jump()

	handle_movement(delta)	

	lastState   = is_on_floor()
	was_on_wall = is_on_wall_only()
	move_and_slide()
	
# Time dash
func _on_dash_timer_timeout() -> void:
	dashing = false
	
# Coyote timer
func _on_coyote_timer_timeout() -> void:
	coyote = false

func _on_jump_timer_timeout() -> void:
	jumping = false

func _on_wall_jump_timer_timeout() -> void:
	wall_jumping = false

func _on_buffer_timer_timeout() -> void:
	jump_buffer = false

func _on_coyote_wall_timer_timeout() -> void:
	coyote_wall = false

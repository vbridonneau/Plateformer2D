extends CharacterBody2D

# Jump related variables
const JUMP_VELOCITY = -300.0
@onready var coyote_timer: Timer = $Timers/CoyoteTimer
@onready var jump_timer:   Timer = $Timers/JumpTimer
var double_jump: bool = false
var lastState:   bool = false # True if the player was on the floor at the vet last frame
var jumping:     bool = false # True if the player has jump previously
var coyote:      bool = false

# Speed control
const ACCELERATION = 60/3
const DECELERATION = 60/6
const SPEED        = 130.0

# Allowing dash
@onready var dash_timer: Timer = $Timers/DashTimer
const DASH_DECELATION:   int   = 240
const DASH_SPEED:        int   = 900
const DIAG_DASH_SPEED:   int   = DASH_SPEED * sqrt(2) / 2
var dashing:             bool  = false
@onready var accel_dash: Node  = $BezierAccelDash
# Dashing is allowed on the flour and in the air only once if the player does not exit the flour dashing
var available_dash:      int   = 1

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

func handle_gravity(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta
		# Enable coyote
		if lastState and not jumping:
			coyote = true
			coyote_timer.start()
	else:
		# Set the number of possible dash so that dash is only possible
		# from the flour or in the aire only once
		available_dash = 1
		jumping        = false
		double_jump    = false

# Handle jump.
func handle_jump() -> void:
	# Check if the jump button is pressed
	if Input.is_action_just_pressed("jump"):
		# Jump is allowed if :
		# - The player is on the flour
		# - The player is in coyote (a little bit after exiting the flour)
		if (is_on_floor() or coyote):
			velocity.y = JUMP_VELOCITY
			jumping    = true
			coyote     = false
			jump_timer.start()
		# Double jump is allowed
		elif jumping and not double_jump:
			velocity.y  = JUMP_VELOCITY
			double_jump = true
			animated_sprite.play("saut")

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
			var dashing_x: bool = false
			var dashing_y: bool = false
			# Count the amount of time since the dash is enabled
			var t:            float = dash_timer.time_left/dash_timer.wait_time
			var acceleration: float = accel_dash.acceleration(t)
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

	lastState = is_on_floor()
	move_and_slide()
	
# Time dash
func _on_dash_timer_timeout() -> void:
	dashing = false
	
# Coyote timer
func _on_coyote_timer_timeout() -> void:
	coyote = false

func _on_jump_timer_timeout() -> void:
	jumping = false

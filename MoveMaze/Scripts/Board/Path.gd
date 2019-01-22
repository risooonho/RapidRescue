# Path - An object which is used to direct `ACTORS` across the board and store `ITEMS`.

extends Spatial

var connections
var moveable
var collectable
# Index Relative to the playing board
var index

var properties = PropertyManager.new()
var traversal = TraversalInfo.new()
var c_storage = CollectableStorage.new()

signal path_pressed

const model_map = {
	# Straight
	'S': preload('res://Objects/3D/Path_Meshs/Straight.tscn'),
	# Corner
	'C': preload('res://Objects/3D/Path_Meshs/Corner.tscn'),
	# T-Intersection
	'T': preload('res://Objects/3D/Path_Meshs/Intersection.tscn')	
}

const init_rotation_map = {
	# Straight
	'NS' : 90,
	'EW' : 0,
	# Corner
	'ES' : 90,
	'NE' : 180,
	'NW' : 270,
	'SW' : 0,
	# T Intersection
	'ESW' : 0,
	'NES' : 90,
	'NEW' : 180,
	'NSW' : 270,
}

var easing = preload('res://Scripts/Easing.gd')
var move_easer = easing.Helper.new(0.6, funcref(easing,'smooth_stop5'))
var rot_easer = easing.Helper.new(0.6, funcref(easing,'smooth_stop5'))

signal target_reached

func init(index, connections, moveable, collectable=null):
	self.index = index
	self.connections = connections
	self.moveable = moveable
	self.collectable = collectable
	_set_model()
	
func _set_model():
	# Update model based on connections
	var content = ''
	for c in connections: if connections[c]: content += (c)
	match content:
		# Straight
		'NS', 'EW':
			add_child(model_map['S'].instance())
		# Corner
		'ES', 'NE', 'NW', 'SW':
			add_child(model_map['C'].instance())
		# T-Intersection
		'ESW', 'NES', 'NEW', 'NSW':
			add_child(model_map['T'].instance())

	rotation_degrees.y = init_rotation_map[content]

func update_index(index):
	self.index = index

func _process(delta):
	
	if move_easer.is_valid():
		_move_toward_target(delta)
		
	if rot_easer.is_valid():
		_rotate_toward_angle(delta)

# Region: Movement

func _move_toward_target(delta):

	move_easer.process(delta)

	if  move_easer.progress >= 1:
		translation = move_easer.target
		move_easer.reset()
		move_easer.enabled = false
		emit_signal("target_reached")
		return

	var difference = move_easer.target - move_easer.start
	var next_pos = move_easer.start + (move_easer.progress * difference)

	translation = next_pos

func set_target(target, is_instant=false):

	if is_instant:
		translation = target
	else:
		move_easer.start = translation
		move_easer.target = target
		move_easer.enabled = true

# Region: Rotation

func _rotate_toward_angle(delta):
	
	rot_easer.process(delta)
	
	if rot_easer.progress >= 1:
		rotation_degrees.y = rot_easer.target
		rot_easer.reset()
		rot_easer.enabled = false
		return

	var difference = rot_easer.target - rot_easer.start
	var next_rot = rot_easer.start + (rot_easer.progress * difference)
	rotation_degrees.y = next_rot

func rotate():
	var names = connections.keys()
	var values = connections.values()
	var temp_values = values.duplicate()

	#Shift Bool
	var count = connections.size()
	for i in count:
		if i-1 >= 0:
			values[i] = temp_values[i - 1]
		else:
			values[i] = temp_values[count - 1]

	# Apply Rotation to connections
	for i in len(connections):
		connections[names[i]] = values[i]
		
	# Set start rotation and target
	
	# If this a new rotation from progress zero, rotate 90 from current roations.
	if rot_easer.progress == 0:
		rot_easer.start = rotation_degrees.y
		rot_easer.target = rotation_degrees.y - 90
		rot_easer.enabled = true
	# If the progress is not 0, rotate 90 degrees from the current target and reset the easer.
	else:
		rot_easer.start = rotation_degrees.y
		rot_easer.target = rot_easer.target - 90
		rot_easer.reset()
		
func _on_Area_input_event(camera, event, click_position, click_normal, shape_idx):
	# Check if index is not null, as null would indicate it's in the HAND
	if event.is_pressed() and index:
		emit_signal("path_pressed", self)

class CollectableStorage:
	"""Store Information regarding a potential collectable."""
	var item

	var is_occupied setget ,occupied

	func occupied():
		return item != null

	func collect():
		var t = item
		item = null
		return t

	func store(item):
		self.item = item

class TraversalInfo:
	"""Used for traversing the board / path finding."""
	var parent
	var h_cost
	var g_cost

	func _init():
		self.g_cost = 0
		self.h_cost = 0


class PropertyManager:
	var _properties = []

	func set(key, value):

		var success = false
		for p in _properties:
			if p.has(key):
				success = true
				p = value

		if !success:
			_properties.append({key : value})

	func get(key):
		for p in _properties:
			if p.has(key):
				return p[key]

	func remove(key):
		for p in _properties:
			if p.has(key):
				_properties.erase(p)

	func has(key):
		for p in _properties:
			if p.has(key):
				return true
		return false
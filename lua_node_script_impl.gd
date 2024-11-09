class_name LuaNodeScriptImpl
extends Node2D

@export var lua_module_path: String
@export var bindings: Dictionary = {}

@onready var vm: LuauVM = SdkBindings.get_default_lua_vm()

var state: Dictionary
var resolved_bindings = {}

func _push_module():
	vm.lua_getglobal("require")
	vm.lua_pushstring(lua_module_path)
	if vm.lua_pcall(1, 1) == vm.LUA_OK:
		# If the call did not error and we got a table, keep it on stack
		if vm.lua_istable(-1):
			return true
		else:
			# This module is invalid because it did not return a table, pop it and log an error
			var found_type = vm.lua_type(-1)
			vm.lua_pop(1)
			print_rich("[color=red]Error loading module %s, expected table but got %s.[/color]" % [lua_module_path, found_type])
			return false
	else:
		# Script execution failed. Pop the error and log it.
		var error = vm.lua_tostring(-1)
		vm.lua_pop(1)
		vm.lua_getglobal("debug")
		vm.lua_getfield(-1, "traceback")
		var traceback = "unknown"
		if vm.lua_pcall(0, 1) == vm.LUA_OK:
			traceback = vm.lua_tostring(-1)
			vm.lua_pop(1)
		else:
			print(vm.lua_tostring(-1))
			vm.lua_pop(1)
		print_rich("[color=red]%s - %s[/color]" % [error, traceback])
		return false

func _ready():
	for key in bindings:
		var value = bindings[key]
		if value.begins_with("res://"):
			value = load(value)
		resolved_bindings[key] = value

	# try to push the module to stack
	if not _push_module(): # [module]
		process_mode = ProcessMode.PROCESS_MODE_DISABLED
		return

	vm.lua_pushdictionary(state) # push state early because we want to read it after call [module, state]

	vm.lua_getfield(-2, "ready") # [module, state, ready]
	if vm.lua_isfunction(-1): # if ready is a function
		vm.lua_pushobject(self) # [module, state, ready, node]
		vm.lua_pushvalue(-3) # [module, state, ready, node, &state]
		vm.lua_pushdictionary(resolved_bindings) # [module, state, ready, node, &state, bindings]
		if vm.lua_pcall(3, 0) == vm.LUA_OK: # [module, state]
			state = vm.lua_todictionary(-1)
		else:
			var error = vm.lua_tostring(-1)
			vm.lua_pop(1)
			print_rich("[color=red]%s[/color]" % error)
			process_mode = ProcessMode.PROCESS_MODE_DISABLED
	else:
		var found_type = vm.lua_type(-1)
		vm.lua_pop(1)
		if found_type != vm.LUA_TNIL:
			print_rich("[color=red]Error in module %s, expected function but got %s.[/color]" % [lua_module_path, found_type])

	vm.lua_pop(1) # pop state - [module]
	vm.lua_pop(1) # pop module - []

func _process(delta: float):
	# TODO this is just for testing:
	if name == "SelectMap":
		var mouse_pos = get_global_mouse_position()
		var tiled_mouse_pos = Vector2(floor(mouse_pos.x / 76) * 76, floor(mouse_pos.y / 37) * 37)
		global_position = tiled_mouse_pos + Vector2(37, 18.5)

	if not _push_module(): # [module]
		process_mode = ProcessMode.PROCESS_MODE_DISABLED
		return
	
	vm.lua_pushdictionary(state) # push state early because we want to read it after call [module, state]

	vm.lua_getfield(-2, "process") # [module, state, process]
	if vm.lua_isfunction(-1): # if process is a function
		vm.lua_pushobject(self) # [module, state, process, node]
		vm.lua_pushvalue(-3) # [module, state, process, node, &state]
		vm.lua_pushdictionary(resolved_bindings) # [module, state, process, node, &state, bindings]
		vm.lua_pushnumber(delta) # [module, state, process, node, &state, bindings, delta]
		if vm.lua_pcall(4, 0) == vm.LUA_OK: # [module, state]
			state = vm.lua_todictionary(-1)
		else:
			var error = vm.lua_tostring(-1)
			vm.lua_pop(1)
			print_rich("[color=red]%s[/color]" % error)
			process_mode = ProcessMode.PROCESS_MODE_DISABLED
	
	vm.lua_pop(1) # pop state - [module]
	vm.lua_pop(1) # pop module - []

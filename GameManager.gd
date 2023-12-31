extends Node
#testtesttestetses123123123
# Players记录所有玩家的信息，以id为key，字段有id，Username，localtion_room，score
#var s_Players = {}
#
#var s_Rooms = {}

#var c_rooms: Dictionary = {}        
var c_player_info: Dictionary = {}  
#var server = null
#var client = null

const ERROR_INEXISTENT_ROOM: String = "There is no room with such id"
const ERROR_GAME_ALREADY_STARTED: String = "Game already started"

var s_rooms: Dictionary = {}
var s_players: Dictionary = {}
var s_maps: Dictionary = {}

var c_rooms: Dictionary = {}
var c_players: Dictionary = {}



var s_next_room_id: int = 0
var s_empty_rooms: Array = []

enum { WAITING, STARTED }

var timestamp = Time.get_datetime_string_from_system(false, true)
	
var map_data_path
var my_map_data
#@rpc("any_peer")
#func join_room(room_name,id):
#	Rooms[room_name]["room_players"].append(id)
#	Players[id]["location_room"] = room_name
	
#@rpc("any_peer")
#func save_date(content,path):
	#var file = FileAccess.open("./"+path, FileAccess.WRITE)
	#file.store_string(content)
	#
#@rpc("any_peer")
#func get_data(path):
	#var file = FileAccess.open("user://"+path, FileAccess.READ)
	#var content = file.get_as_text()
	#return content
#--------------定义游戏数据传输的结构-----------------------#


class PlayerDetails:
	var myself_id 				#
	var PlayerX				#*array[pos,pos.....] 对应pos_list_p1 = [] pos_list_p2 = []
	var pos_clicked				
	var mylocal_room_id
	var score
	var timestamp
	var time_after_game
	#(pos_clicked, PlayerX, myself_id, timestamp, time_after_game,timeout)
	func _init(myself_id,PlayerX,pos_clicked,mylocal_room_id, score,timestamp,time_after_game):
		self.myself_id = myself_id
		self.PlayerX = PlayerX
		self.pos_clicked = pos_clicked
		self.score = score
		self.mylocal_room_id = mylocal_room_id
		self.timestamp = timestamp
		self.time_after_game = time_after_game

#该函数为客户端 按钮点击发起
@rpc("any_peer")		
func create_room(info: Dictionary) -> void:
	print("func create_room entered!")
	timestamp = Time.get_datetime_string_from_system(false, true)
	var sender_id: int = multiplayer.get_remote_sender_id()
	
	
	var room_id: int
	if s_empty_rooms.is_empty():
		room_id = s_next_room_id
		s_next_room_id += 1
	else:
		room_id = s_empty_rooms.pop_back()
		
	s_rooms[room_id] = {
		creator = sender_id,
		players_in_room = {},
		players_done = 0,
		state = WAITING,
		selected_map_file = "",
		selected_map_data = {},
		room_id = room_id
	}
	
	
	_add_player_to_room(room_id, sender_id, info)
	# 设置客户端的提示语your roomX is created\nwaiting for the other player to join
	var create_text = str("           your room") + str(room_id) + str(" is created\nwaiting for the other player to join")
	change_create_text.rpc_id(sender_id, create_text)
	print(str(timestamp) + " Room created by " + str(sender_id))

#客户端 点击 发起，数据逻辑处理在服务端
@rpc("any_peer")	
func join_room(room_id: int, info: Dictionary) -> void:
	print("func join_room entered!")
	var sender_id: int = multiplayer.get_remote_sender_id()
	
	#if not rooms.keys().has(room_id):
	#	rpc_id(sender_id, "show_error", ERROR_INEXISTENT_ROOM)
	#	get_tree().root.disconnect_peer(sender_id)
	#elif rooms[room_id].state == STARTED:
	#	rpc_id(sender_id, "show_error", ERROR_GAME_ALREADY_STARTED)
	#	get_tree().get_root().disconnect_peer(sender_id)
	#else:
	_add_player_to_room(room_id, sender_id, info)
	
	var room: Dictionary = _get_room(sender_id)
	room.state = STARTED
	# 通知客户端更新label显示
	var client_control_label_str = str("Your room") + str(room.room_id) + " is matched. Please click Draw Map to continue."
	# get_tree().root.get_children()[1].get_node("Label").text 
	for player_id in room.players_in_room:
		change_client_control.rpc_id(player_id, client_control_label_str)
	

@rpc("any_peer")
func change_client_control(value):
	get_tree().root.get_children()[1].get_node("Label").text = value
	get_tree().root.get_children()[1].get_node("Host").visible = false
	
# 服务器端 更新数据
func _add_player_to_room(room_id: int, id: int, info: Dictionary) -> void:
	print("func add_player_to_room entered!")
	# Update data structures
	s_rooms[room_id].players_in_room[id] = info
	s_players[id].room_id = room_id

	
	# Send the room id to the new player
	#rpc_id(id, "update_room", room_id)
	
	# Notify all connected players (in the room) about it (including the new one)
	#for player_id in rooms[room_id].players:
	#	rpc_id(player_id, "register_player", id, info)
	
	# Send the rest of the players to the new player
	#for other_player_id in rooms[room_id].players:
	#	if other_player_id != id:
	#		rpc_id(id, "register_player", other_player_id, rooms[room_id].players[other_player_id])
		
		
@rpc("any_peer")
func start_game() -> void:
	print("func start_game entered!")
	var sender_id: int = multiplayer.get_remote_sender_id()
	
	var room: Dictionary = _get_room(sender_id)
	
	for player_id in room.players_in_room:
		StartGame.rpc_id(player_id)

func _get_room(player_id: int) -> Dictionary:
	var myroom_id = s_players[player_id].room_id
	return s_rooms[myroom_id]

####Load Game here. And hide our connect menu 
@rpc("any_peer")
func StartGame():
	var current_scene = get_tree().get_root().get_child(get_tree().get_root().get_child_count() - 1)
	current_scene.queue_free()
	var scene = load("res://Main.tscn").instantiate()
	get_tree().root.add_child(scene)
	get_tree().get_current_scene().hide()
	
	var my_unique_id: int = multiplayer.get_unique_id()
	var room: Dictionary = _get_room(my_unique_id)
	load_map_to_client_main(room.selected_map_data)
	

@rpc("any_peer")
func load_map_to_client_main(map_data):
	for key in map_data.map:
		var item = map_data.map[key]
		get_tree().get_root().get_child(get_tree().get_root().get_child_count() - 1).get_node("TileMap").set_cell(item.layer,item.coords,item.source_id,item.atlas_coords)


@rpc("any_peer")
func _set_room_by_frame(rooms,players,maps):
	
	if get_tree().current_scene.rooms!= rooms: 
		get_tree().current_scene.rooms= rooms
	if get_tree().current_scene.maps!= maps: 
		get_tree().current_scene.maps= maps	
	c_rooms = rooms
	c_players = players
	
@rpc("any_peer")		
func register_player(id: int, info: Dictionary) -> void:
	c_player_info[id] = info

#######In-game function

var click_events = []
var can_process_input = true
var input_counter = 0
var N = 5
var input_stage = 1
#Tile color
var white = Vector2i(0,2)  #白色在stage 1
var black = Vector2i(0,0)  #黑色在stage 2动
var red = Vector2i(0,1)    #红色禁止通行






########## process_click#############
var player1_pos = Vector2i(0,0)
var player1_id  = 0
var player1_time = 0
var player2_pos = Vector2i(0,0)
var player2_id  = 0
var player2_time = 0
var playerx_winner = 0



#@rpc("any_peer")
#func timeout(PlayerX,myself_id,timeout):
#	if timeout == true:
#		pass_click()
#		process_click(pos_clicked, PlayerX, myself_id, timestamp,time_after_game,timeout)

##game_inroom example 
#game_inroom = {inroom_id_0 = {}, inroom_id_1 = {},......  }
#inroom_id_0 = {"room_id": 0"
				#"pos_p1":
				#"pos_p2":
				#"id_p1":
				#"id_p2":
				#time_after_game_p1:
				#time_after_game_p2:
				#timestamp_p1:
				#timestamp_p2:
#}



#-------------------------------处理客户端信息-----------------------#
#var player_details = PlayerDetails.new("player1", 1, Vector2(10, 20), 0, "room123")

## 更新得分
#player_details.score += 10
#
## 更新位置
#player_details.pos = Vector2(30, 40)
#class PlayerDetails:
#    # ... 其他代码 ...
#
#    func update_score(new_score):
#        score = new_score
#
## 使用方法更新得分
#player_details.update_score(50)
## 修改房间ID
#player_details.room_id = "room456"

#class PlayerDetails:
#	var myself_id 				#
#	var PlayerX				#*array[pos,pos.....] 对应pos_list_p1 = [] pos_list_p2 = []
#	var pos_clicked				
#	var mylocal_room_id
#	var score
#	var timestamp
#	var time_after_game
#	#(pos_clicked, PlayerX, myself_id, timestamp, time_after_game,timeout)
#	func _init(myself_id,PlayerX,pos_clicked,mylocal_room_id, score,timestamp,time_after_game):
#		self.myself_id = myself_id
#		self.PlayerX = PlayerX
#		self.pos_clicked = pos_clicked
#		self.score = score
#		self.mylocal_room_id = mylocal_room_id
#		self.timestamp = timestamp
#		self.time_after_game = time_after_game

#@rpc("any_peer")
#func timeout(PlayerX,myself_id,timeout):
#	if timeout == true:
#		pass_click()
#		process_click(pos_clicked, PlayerX, myself_id, timestamp, time_after_game,timeout)

@rpc("any_peer")
func timeout(pos_clicked, PlayerX, myself_id, timestamp, time_after_game,timeout,mylocal_room_id):
	if timeout == true:
		pos_clicked = Vector2i(999,999)
		process_click(pos_clicked, PlayerX, myself_id, timestamp, time_after_game,timeout,mylocal_room_id)


var playinfo = {} #*playinfo = { room_id: player_details} *player_details是一个类
@rpc("any_peer")
func process_click(pos_clicked, PlayerX, myself_id, timestamp, time_after_game,timeout,mylocal_room_id):
	
	var player_details = PlayerDetails.new(myself_id, PlayerX, pos_clicked, mylocal_room_id, 0,timestamp,time_after_game)
	if not playinfo.has(mylocal_room_id):
		playinfo[mylocal_room_id] = []
	playinfo[mylocal_room_id].append(player_details)
#	print("11111")
#	print(playinfo)
	process_click_send(mylocal_room_id)

func process_click_send(mylocal_room_id):
	var first_player_details = null
	var second_player_details = null
	var myplayer1_pos = null
	var myplayer2_pos = null
	var myplayerx_winner = null  
	var player1_id = null
	var player2_id = null
	if playinfo[mylocal_room_id].size() == 2:
		print("yes, there are two size")
		if playinfo[mylocal_room_id][0].PlayerX == 1:
			first_player_details = playinfo[mylocal_room_id][0]
			second_player_details = playinfo[mylocal_room_id][1]
		else:
			first_player_details = playinfo[mylocal_room_id][1]
			second_player_details = playinfo[mylocal_room_id][0]
		if first_player_details.myself_id != second_player_details.myself_id:
			myplayer1_pos = first_player_details.pos_clicked
			myplayer2_pos = second_player_details.pos_clicked
			print("22222222222222")
			print(myplayer1_pos)
			print(myplayer2_pos)
		player1_id = first_player_details.myself_id
		player2_id = second_player_details.myself_id
		if myplayer1_pos == myplayer2_pos:
			if first_player_details.time_after_game < second_player_details.time_after_game:
				myplayerx_winner =  first_player_details.PlayerX
			else:
				myplayerx_winner =  second_player_details.PlayerX
		else: 
			myplayerx_winner = 0
		rpc_id(player1_id, "set_cell_color_rpc", myplayer1_pos, myplayer2_pos, myplayerx_winner)
		rpc_id(player2_id, "set_cell_color_rpc", myplayer1_pos, myplayer2_pos, myplayerx_winner)
		playinfo.erase(mylocal_room_id)

			
#func pass_click():
#	#if pos_clicked == Vector2i(999,999), then pass
#	var pos_clicked = Vector2i(999,999)
		
		
		
	
#同步tile
@rpc("any_peer")
func sync_score(player1score, player2score):
	get_tree().root.get_children()[2].get_node("ScoreDisplay/Player1Score").text = player1score
	get_tree().root.get_children()[2].get_node("ScoreDisplay/Player2Score").text = player2score

@rpc("any_peer")
func sync_tile_change_rpc(pos_clicked, current_atlas_coords, new_tile_alt):
	# 在这里应用从服务器接收到的改变set_cell(main_layer, pos_clicked, main_atlas_id, current_atlas_coords, new_tile_alt)
	get_tree().root.get_children()[2].get_node("TileMap").sync_tile_change(pos_clicked, current_atlas_coords, new_tile_alt)

	#print("set tile in the client")
#同步stage and counter
@rpc("any_peer")
func sync_input_stage_and_counter(new_stage,new_counter):
	get_tree().root.get_children()[2].get_node("TileMap").input_stage = new_stage
	get_tree().root.get_children()[2].get_node("TileMap").input_counter = new_counter

#重置input使用
@rpc("any_peer")
func resume_input():
	get_tree().root.get_children()[2].get_node("TileMap").can_process_input_GM = true   #print("Reset" + str(PlayerX))
			
		
@rpc("any_peer")
func set_cell_color_rpc(player1_pos, player2_pos, playerx_winner):
	get_tree().root.get_children()[2].get_node("TileMap").set_cell_color(player1_pos, player2_pos, playerx_winner)

#----------------------------------log file—-----------------------------------#
@rpc("any_peer")
func logging_server(file_name,content):
	var path = "user://" + file_name
	var file = FileAccess.open(path, FileAccess.READ_WRITE)
	if FileAccess.file_exists(path):

		if file:
			var json_string = JSON.stringify(content)
			file.seek_end()
			file.store_line(json_string + "\n")
			file.close()
	else:
		file= FileAccess.open(path, FileAccess.WRITE)
		if file:
			var json_string = JSON.stringify(content)
			file.seek_end()
			file.store_line(json_string + "\n")
			file.close()


#----------------------------------save user map to server—-----------------------------------#
@rpc("any_peer")
func save_map_to_server(file_name,map_data):
	var path = "user://" + file_name
	var file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(var_to_str(map_data))
	s_maps[path] = {
		map_path = path
	}
	


@rpc("any_peer")
func load_map(path):
	# 服务端读取地图数据，客户端根据服务器端传来的地图数据在本地渲染出来
	var file = FileAccess.open(path, FileAccess.READ)
	var content = file.get_as_text()
	
	my_map_data = str_to_var(content)
	
	var sender_id: int = multiplayer.get_remote_sender_id()
	
	var room: Dictionary = _get_room(sender_id)
	room.selected_map_file = path
	room.selected_map_data = my_map_data
	
	for player_id in room.players_in_room:
		load_map_to_client.rpc_id(player_id,my_map_data)
	

@rpc("any_peer")
func load_map_to_client(map_data):
	var scene = load("res://user_setting.tscn").instantiate()
	get_tree().root.add_child(scene)
	get_tree().get_current_scene().hide()	
	for key in map_data.map:
		var item = map_data.map[key]
		get_tree().get_root().get_child(get_tree().get_root().get_child_count() - 1).get_node("TileMap").set_cell(item.layer,item.coords,item.source_id,item.atlas_coords)

	
@rpc("any_peer")
func change_create_text(create_text):
	get_tree().root.get_children()[1].get_node("Label").text = create_text
	

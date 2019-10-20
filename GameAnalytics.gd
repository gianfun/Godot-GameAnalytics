extends Node
# GameAnalytics <https://gameanalytics.com/> native GDScript REST API implementation
# Cross-platform. Should work in every platform supported by Godot
# Adapted from REST_v2_example.py by Cristiano Reis Monteiro <cristianomonteiro@gmail.com> Abr/2018

""" Procedure -->
1. make an init call
	- check if game is disabled
	- calculate client timestamp offset from server time
2. start a session
3. add a user event (session start) to queue
4. add a business event + some design events to queue
5. submit events in queue
6. add some design events to queue
7. add session_end event to queue
8. submit events in queue
"""

const UUID = preload("uuid.gd")

var DEBUG = false
# var returned
# var response_data
# var response_code

var uuid = UUID.v4()

# For some reason GameAnalytics only accepts lower case. Weird but happened to me
var platform = OS.get_name().to_lower()
#var os_version = OS.get_name()
# Couldn't find a way to get OS version yet. Need to adapt for iOS or anything else
var os_version = "android 4.4.4"
# warning-ignore:unused_class_variable
var sdk_version = 'rest api v2'
# warning-ignore:unused_class_variable
var device = OS.get_model_name().to_lower()
# warning-ignore:unused_class_variable
var manufacturer = OS.get_name().to_lower()

# game information
# warning-ignore:unused_class_variable
var build_version = 'alpha 0.0.1'
# warning-ignore:unused_class_variable
var engine_version = 'Godot 3.0.2'

# sandbox game keys
var game_key
var secret_key

# sandbox API urls
var base_url = "http://sandbox-api.gameanalytics.com"
var url_init
var url_events

# settings
var verbose_log = false


# global state to track changes when code is running
var state_config = {
	# the amount of seconds the client time is offset by server_time
	# will be set when init call receives server_time
	'client_ts_offset': 0,
	# will be updated when a new session is started
	'session_id': uuid,
	# set if SDK is disabled or not - default enabled
	'enabled': true,
	# event queue - contains a list of event dictionaries to be JSON encoded
	'event_queue': []
}

var requests = HTTPClient.new()



# adding an event to the queue for later submit
func add_to_event_queue(event_dict):
#    if not isinstance(event_dict, dict):
#        return
	#annotate_event_with_default_values(event_dict)
	#annotate_event_with_default_values()
	# Load saved events, if any
	var f = File.new()
	if f.file_exists("user://event_queue"):
		f.open("user://event_queue", File.READ)
		state_config['event_queue'] = f.get_var()
		f.close()

	state_config['event_queue'].append(event_dict)

	#Save to file
	f.open("user://event_queue", File.WRITE)
	f.store_var(state_config['event_queue'])
	f.close()

# requesting init URL and returning result
func request_init():
	# Get version number on Android. Need something similar for iOS
	if platform == "android":
		var output = []
		# TODO: Why is this not used?
		var _pid = OS.execute("getprop", ["ro.build.version.release"], true, output)
		# Trimming new line char at the end
		output[0] = output[0].substr(0, output[0].length() - 1)
		os_version = platform + " " + output[0]

	var init_payload = {
		'platform': platform,
		'os_version': os_version,
		'sdk_version': sdk_version
	}

	# generate session id
	generate_new_session_id()

	# Refreshing url_init since game key might have been changed externally
	url_init = "/v2/" + game_key + "/init"
	#var queryString = requests.query_string_from_dict(init_payload)
	#var init_payload_json = json.dumps(init_payload)
	var init_payload_json = to_json(init_payload)

	var headers = [
		"Authorization: " + Marshalls.raw_to_base64(hmac_sha256(init_payload_json, secret_key)),
		"Content-Type: application/json"]
	#var headers = ["\"Authorization: " +  Marshalls.raw_to_base64(hmac_sha256(init_payload_json, secret_key)) + "\"", "\"Content-Type: application/json\""]
	print(Marshalls.raw_to_base64(hmac_sha256(init_payload_json, secret_key)))
	#response_dict = None
	#status_code = None
	#var response_dict
	var status_code

	if DEBUG:
		print(base_url)
		print(url_init)
		print(init_payload_json)
		print(Marshalls.raw_to_base64(hmac_sha256(init_payload_json, secret_key)))

	#try:
	# TODO: Fix unused error
	var _err = requests.connect_to_host(base_url,80)

		# Wait until resolved and connected
	while requests.get_status() == HTTPClient.STATUS_CONNECTING or requests.get_status() == HTTPClient.STATUS_RESOLVING:
		requests.poll()
		print("Connecting..")
		OS.delay_msec(500)

	# Error catch: Could not connect
	#assert(requests.get_status() == HTTPClient.STATUS_CONNECTED)
	#var h = [to_json(headers)]
	var init_response = requests.request(HTTPClient.METHOD_POST, url_init, headers, init_payload_json)
#    except:
#        post_to_log("Init request failed!")
#        sys.exit()
	while requests.get_status() == HTTPClient.STATUS_REQUESTING:
		# Keep polling until the request is going on
		requests.poll()
		print("Requesting..")
		OS.delay_msec(500)

	if requests.has_response():
		# If there is a response..
		headers = requests.get_response_headers_as_dictionary() # Get response headers
		print("code: ", requests.get_response_code()) # Show response code
		print("**headers:\\n", headers) # Show headers

		# Getting the HTTP Body

		if requests.is_response_chunked():
			# Does it use chunks?
			print("Response is Chunked!")
		else:
			# Or just plain Content-Length
			var bl = requests.get_response_body_length()
			print("Response Length: ",bl)

		# This method works for both anyway

		var rb = PoolByteArray() # Array that will hold the data

		while requests.get_status() == HTTPClient.STATUS_BODY:
			# While there is body left to be read
			requests.poll()
			var chunk = requests.read_response_body_chunk() # Get a chunk
			if chunk.size() == 0:
				# Got nothing, wait for buffers to fill a bit
				OS.delay_usec(1000)
			else:
				rb = rb + chunk # Append to read buffer

		# Done!

		print("bytes got: ", rb.size())
		var text = rb.get_string_from_ascii()
		print("Text: ", text)

	#status_code = init_response.status_code
	status_code = requests.get_response_code()
	#try:
	# TODO: Why is this not used?
	var _response_dict = to_json(init_response)
#    except:
#        response_dict = None

#    if not isinstance(status_code, (long, int)):
#        post_to_log("---- Submit Init ERROR ----")
#        post_to_log("URL: " + str(url_init))
#        post_to_log("Payload JSON: " + str(init_payload_json))
#        post_to_log("Headers: " + str(headers))
#    var a
#    if status_code is null:
#        a = ""
#    else a = "Returned: " + str(status_code) + " response code."

	var response_string = (status_code)

	if status_code == 401:
		post_to_log("Submit events failed due to UNAUTHORIZED.")
		post_to_log("Please verify your Authorization code is working correctly and that your are using valid game keys.")
		#sys.exit()

	if status_code != 200:
		post_to_log("Init request did not return 200!")
		post_to_log(response_string)
#        if isinstance(response_dict, dict):
#            post_to_log(response_dict)
#        elif isinstance(init_response.text, basestring):
#            post_to_log("Response contents: " + init_response.text)
		#sys.exit()

	# init request ok --> get values
#    if 'server_ts' not in response_dict or not isinstance(response_dict['server_ts'], (int, long)):
#        post_to_log("Init request failed! Did not return proper server_ts..")
#        sys.exit()

#    if 'enabled' in response_dict and !response_dict['enabled']:
#        state_config['enabled'] = false

	#return Vector2(response_dict, status_code)
	return status_code


# submitting all events that are in the queue to the events URL
func submit_events():
	#try:
	# Refreshing url_events since game key might have been changed externally
	url_events = "/v2/" + game_key + "/events"
	var event_list_json = to_json(state_config['event_queue'])
#    except:
#        post_to_log("Event queue failed JSON encoding!")
#        event_list_json = None
#        return

#    if event_list_json is null:
#        return


	# create headers with authentication hash
	var headers = [
		"Authorization: " +  Marshalls.raw_to_base64(hmac_sha256(event_list_json, secret_key)),
		"Content-Type: application/json"]


	# TODO: Fix unused error
	var _err = requests.connect_to_host(base_url,80)

		# Wait until resolved and connected
	while requests.get_status() == HTTPClient.STATUS_CONNECTING or requests.get_status() == HTTPClient.STATUS_RESOLVING:
		requests.poll()
		print("Connecting..")
		OS.delay_msec(500)


	#try:
	# TODO: Why is this not used?
	var _events_response = requests.request(HTTPClient.METHOD_POST, url_events, headers, event_list_json)
#    except Exception as e:
#        post_to_log("Submit events request failed!")
#        post_to_log(e.reason)
#        return (None, None)
	while requests.get_status() == HTTPClient.STATUS_REQUESTING:
		# Keep polling until the request is going on
		requests.poll()
		print("Requesting..")
		OS.delay_msec(500)

	if requests.has_response():
		# If there is a response..
		headers = requests.get_response_headers_as_dictionary() # Get response headers
		print("code: ", requests.get_response_code()) # Show response code
		print("**headers:\\n", headers) # Show headers

		# Getting the HTTP Body

		if requests.is_response_chunked():
			# Does it use chunks?
			print("Response is Chunked!")
		else:
			# Or just plain Content-Length
			var bl = requests.get_response_body_length()
			print("Response Length: ",bl)

		# This method works for both anyway

		var rb = PoolByteArray() # Array that will hold the data

		while requests.get_status() == HTTPClient.STATUS_BODY:
			# While there is body left to be read
			requests.poll()
			var chunk = requests.read_response_body_chunk() # Get a chunk
			if chunk.size() == 0:
				# Got nothing, wait for buffers to fill a bit
				OS.delay_usec(1000)
			else:
				rb = rb + chunk # Append to read buffer

		# Done!

		print("bytes got: ", rb.size())
		var text = rb.get_string_from_ascii()
		print("Text: ", text)

	#var status_code = events_response.status_code
	var status_code = requests.get_response_code()
	#try:
	#var response_dict = events_response.json()
#    except:
#        response_dict = None

	#print_verbose("Submit events response: " + str(response_dict))

	# check response code
	#status_code_string = ("" if status_code is None else "Returned: " + str(status_code) + " response code.")
	var status_code_string = str(status_code)
	if status_code == 400:
		post_to_log(status_code_string)
		post_to_log("Submit events failed due to BAD_REQUEST.")
		# If bad request, then some parameter is very wrong. Eliminating queue in order to no hold submission
		# In future instances where the bad parameter is no longer existing
		state_config['event_queue'] = []
		var dir = Directory.new()
		dir.remove("user://event_queue")
#        if isinstance(response_dict, (dict, list)):
#            post_to_log("Payload found in response. Contents can explain what fields are causing a problem.")
#            post_to_log(events_response.text)
#            sys.exit()
#    elif status_code == 401:
#        post_to_log(status_code_string)
#        post_to_log("Submit events failed due to UNAUTHORIZED.")
#        post_to_log("Please verify your Authorization code is working correctly and that your are using valid game keys.")
#        sys.exit()
	elif status_code != 200:
		post_to_log(status_code_string)
		post_to_log("Submit events request did not succeed! Perhaps offline.. ")
#        sys.exit()

#    if not isinstance(response_dict, dict):
#        post_to_log("Submit events request returned 200, but reading and JSON decoding response failed..")
#        post_to_log(events_response.text)
#        sys.exit()

	if status_code == 200:
		post_to_log("Events submitted !")
		# clear event queue
		# If submitte successfully, then clear queue and remove queu file to not create duplicate entries
		state_config['event_queue'] = []
		var dir = Directory.new()
		dir.remove("user://event_queue")

	else:
		post_to_log("Event submission FAILED!")

	return status_code


# ------------------ HELPER METHODS ---------------------- #


func generate_new_session_id():
	state_config['session_id'] = uuid
	print_verbose("Session Id: " + state_config['session_id'])


func update_client_ts_offset(server_ts):
	# calculate client_ts using offset from server time
	var client_ts = OS.get_unix_time_from_datetime(OS.get_datetime())
	var offset = client_ts - server_ts

	# If the difference is too small, ignore it
	state_config['client_ts_offset'] = 0 if offset < 10 else offset
	print_verbose('Client TS offset calculated to: ' + str(offset))


func get_test_business_event_dict():
	var event_dict = {
		'category': 'business',
		'amount': 999,
		'currency': 'USD',
		'event_id': 'Weapon:SwordOfFire',  # item_type:item_id
		'cart_type': 'MainMenuShop',
		'transaction_num': 1,  # should be incremented and stored in local db
		'receipt_info': {'receipt': 'xyz', 'store': 'apple'}  # receipt is base64 encoded receipt
	}
	return event_dict


func get_test_user_event():
	var event_dict = {
		'category': 'user'
	}
	return event_dict


func get_test_session_end_event(length_in_seconds):
	var event_dict = {
		'category': 'session_end',
		'length': length_in_seconds
	}
	return event_dict


func get_test_design_event(event_id, value):
	var event_dict = {
		'category': 'design',
		'event_id': event_id,
		'value': value
	}
	dict_assign(event_dict, annotate_event_with_default_values())
	#annotate_event_with_default_values()
#    if isinstance(value, (int, long, float)):
#        event_dict['value'] = value
	return event_dict

static func dict_assign(target, patch):
    for key in patch:
        target[key] = patch[key]

# add default annotations (will alter the dict by reference)
#func annotate_event_with_default_values(event_dict):
func annotate_event_with_default_values():
	# TODO: Why is this not used?
	# var now_ts = OS.get_datetime()
	# datetime.utcnow()
	# calculate client_ts using offset from server time
	#var client_ts = calendar.timegm(now_ts.timetuple()) - state_config['client_ts_offset']
	var client_ts = OS.get_unix_time_from_datetime(OS.get_datetime())

	# TEST IDFA / IDFV
	# var idfa = 'AEBE52E7-03EE-455A-B3C4-E57283966239'
	var idfa = OS.get_unique_id().to_lower()
	# var idfv = 'AEBE52E7-03EE-455A-B3C4-E57283966239'

	var default_annotations = {
		'v': 2,                                     # (required: Yes)
		'user_id': idfa,                            # (required: Yes)
		#'ios_idfa': idfa,                           # (required: No - required on iOS)
		#'ios_idfv': idfv,                           # (required: No - send if found)
		# 'google_aid'                              # (required: No - required on Android)
		# 'android_id',                             # (required: No - send if set)
		# 'googleplus_id',                          # (required: No - send if set)
		# 'facebook_id',                            # (required: No - send if set)
		# 'limit_ad_tracking',                      # (required: No - send if true)
		# 'logon_gamecenter',                       # (required: No - send if true)
		# 'logon_googleplay                         # (required: No - send if true)
		#'gender': 'male',                           # (required: No - send if set)
		# 'birth_year                               # (required: No - send if set)
		# 'progression                              # (required: No - send if a progression attempt is in progress)
		#'custom_01': 'ninja',                       # (required: No - send if set)
		# 'custom_02                                # (required: No - send if set)
		# 'custom_03                                # (required: No - send if set)
		'client_ts': client_ts,                     # (required: Yes)
		'sdk_version': sdk_version,                 # (required: Yes)
		'os_version': os_version,                   # (required: Yes)
		'manufacturer': manufacturer,                    # (required: Yes)
		'device': device,                      # (required: Yes - if not possible set "unknown")
		'platform': platform,                       # (required: Yes)
		'session_id': state_config['session_id'],   # (required: Yes)
		#'build': build_version,                     # (required: No - send if set)
		'session_num': 1,                           # (required: Yes)
		#'connection_type': 'wifi',                  # (required: No - send if available)
		# 'jailbroken                               # (required: No - send if true)
		#'engine_version': engine_version            # (required: No - send if set by an engine)
	}
	#event_dict.update(default_annotations)
	#state_config['event_queue'].append(default_annotations)
	return default_annotations

func print_verbose(message):
	print(message)
	if verbose_log:
		post_to_log(message)

func post_to_log(message):
	print(message)
	pass





func pool_byte_array_from_hex(hex):
	var out = PoolByteArray()

	for idx in range(0, hex.length(), 2):
		var hex_int = ("0x" + hex.substr(idx, 2)).hex_to_int()
		out.append(hex_int)

	return out

# TODO: This sucks, but its what we have right now
# Returns the hex encoded sha256 hash of buffer
func sha256(buffer):
	var path = "user://__ga__sha256_temp"
	var file = File.new()
	file.open(path, File.WRITE)
	file.store_buffer(buffer)
	file.close()
	var sha_hash = file.get_sha256(path)

	Directory.new().remove(path)

	return sha_hash

func hmac_sha256(message, key):
	# Hash key if length > 64
	if key.length() <= 64:
		key = key.to_utf8()
	else:
		key = key.sha256_buffer()

	# Right zero padding if key length < 64
	while key.size() < 64:
		key.append(0)


	var inner_key = PoolByteArray()
	var outer_key = PoolByteArray()

	for idx in range(0, 64):
		outer_key.append(key[idx] ^ 0x5c)
		inner_key.append(key[idx] ^ 0x36)


	var inner_hash = pool_byte_array_from_hex(sha256(inner_key + message.to_utf8()))
	var outer_hash = pool_byte_array_from_hex(sha256(outer_key + inner_hash))

	return outer_hash



	#	# For some reason, "Windows" is not recognized by GameAnaytics. Guess they only expect mobile platforms
	if platform == "Windows":
		platform = "ios"
#
	if os_version == "Windows":
		os_version = "ios 8.2"
	# 1. init call
	#init_response, init_response_code = request_init()
#	var init_response = request_init()
#	var init_response_code = init_response

	# calculate client_ts offset from server
	#update_client_ts_offset(init_response['server_ts'])

#	post_to_log("Init call successful !")
#	print_verbose("Init response: " + str(init_response))
#
#	# 2. send events (only one business event)
#	if !state_config['enabled']:
#		post_to_log("SDK disabled. Will not continue event submit.")
#		#sys.exit()

	# generate session id
	#generate_new_session_id()
	#annotate_event_with_default_values()
#	add_to_event_queue(get_test_design_event("player:new_level", 1))
#	add_to_event_queue(get_test_design_event("player:new_level", 2))
#	add_to_event_queue(get_test_design_event("player:played_video", 3))
#
#	returned = submit_events()

#	# add session start event (user event)
#	add_to_event_queue(get_test_user_event())
#
#	# add business event
#	add_to_event_queue(get_test_business_event_dict())
#
#	# add design events
#	add_to_event_queue(get_test_design_event("player:death:shotgun", 0))
#	add_to_event_queue(get_test_design_event("player:kill:blue_yeti", 23.9))
#	add_to_event_queue(get_test_design_event("player:kill:black_yeti", 90.3))
#
#	# submit the event queue and clear it
#	returned = submit_events()
##    response_data = returned.x
##    response_code = returned.y
#
#	# add more design events
#	add_to_event_queue(get_test_design_event("player:kill:black_yeti", 90.9))
#	add_to_event_queue(get_test_design_event("player:death:black_yeti", 0))
#	add_to_event_queue(get_test_design_event("player:kill:golden_goose", 21.5))
#
#	# end session: add session end event
#	add_to_event_queue(get_test_session_end_event(200))
#
#	# submit the event queue and clear it
#	returned = submit_events()
#    response_data = returned.x
#    response_code = returned.y

	#sys.exit()
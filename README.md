# Godot-GameAnalytics

Apr 23, 2018 - Cristiano Reis Monteiro <cristianomonteiro@gmail.com>

Native GDScript for GameAnalytics in Godot

When I first started learning Godot I notice the limitation when it comes to capture game analytics. The vast majority of options are incomplete in the sense that supports only one platform, missing functions etc, besides the regular need to recompile the engine, rebuild export templates, etc.

In search of a native, cross platform solution, identified that https://gameanalytics.com/ had a REST API sample in Python

Worked to convert it to GDScript (hardest part was implementing HMAC-SHA256).

The result is here.

Yes, the code is crude, poluted, redundant, etc, but it works. Don't complain, go fix it and share the result.

PLEASE NOTE: This GDScript makes use of https://github.com/xsellier/godot-uuid, so, download uuid.gd and place in the same folder as GameAnalytics.gd

USAGE INSTRUCTIONS:

. Add GameAnalytics.gd and uuid.gd to your root resources folder

. Add that to your main .gd:

```python
extends Node

func _ready():
  GameAnalytics.game_key = <your_game_key_supplied_by_GameAnalytics>
  GameAnalytics.secret_key = <your_secret_key_supplied_by_GameAnalytics>
  GameAnalytics.base_url = "http://api.gameanalytics.com"

  # Run once per session
  init_response = GameAnalytics.request_init()

  # Add events to queue
  GameAnalytics.add_to_event_queue(GameAnalytics.get_test_design_event("player:new_level", 1))
  GameAnalytics.add_to_event_queue(GameAnalytics.get_test_design_event("player:new_level", 2))

  # Submit events and flush queue - return code will indicate success (200) or failure (400, 401, 404)
  var returned = GameAnalytics.submit_events()
```

Study GameAnalytics.gd and GameAnalytics REST API page to understand what else can be submitted.

NOTE: While testing on my Windows machine, GameAnalytics refused "Windows" as a valid os/platform, so I put this code before GameAnalytics.request_init() to work around that. YMMV

```python
	if GameAnalytics.platform == "Windows":
		GameAnalytics.platform = "android"

	if GameAnalytics.os_version == "Windows":
		GameAnalytics.os_version = "android 4.4.4"
 ```
 
TODO

. Correctly calculate client_ts offset

. Enable GZip compression (partially done / commented out)

. Better error treatment

. Fix comments and clean up code

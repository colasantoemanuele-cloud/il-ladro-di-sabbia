extends SceneTree
## Rigenera gli asset su disco che servono fuori dal gioco (icona dell'app):
##   godot --headless --path . --script tools/genera_asset.gd
## Il resto della pixel art nasce a runtime da scripts/art/pixel_art.gd.

func _init() -> void:
	DirAccess.make_dir_recursive_absolute("res://assets")
	var img := PixelArt.icona_app()
	img.save_png("res://assets/icon.png")
	print("icona salvata: %dx%d" % [img.get_width(), img.get_height()])
	quit()

# Hides IrohServer and IrohClient from the rest of the build
# Usage note:
# The extension is native-only, so on platforms where it isn't loaded
# (e.g. web export, or a checkout without the plugin installed) these
# class names are undefined and any script that references them fails to
# compile. It must be pulled in with load() ONLY after confirming
# ClassDB.class_exists("IrohServer"). See SetupIrohGame.

static func make_server() -> MultiplayerPeer:
	return IrohServer.start()


static func make_client(connection_string: String) -> MultiplayerPeer:
	print("attempting to dial %s via iroh" % connection_string)
	return IrohClient.connect(connection_string)

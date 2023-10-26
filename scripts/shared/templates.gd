extends Node

var obs_stats_template = "" \
	+ "CPU Usage: [b]{cpuUsage}[/b]\n" \
	+ "Memory Usage: [b]{memoryUsage}[/b]\n" \
	+ "Disk Space: [b]{availableDiskSpace}[/b]\n" \
	+ "Active FPS: [b]{activeFps}[/b]\n" \
	+ "Frame Render Time: [b]{averageFrameRenderTime}[/b]\n" \
	+ "Frames Rendered/Skipped: [b]{renderTotalFrames}[/b]/[b]{renderSkippedFrames}[/b]\n" \
	+ "Total Rendered/Skipped: [b]{outputTotalFrames}[/b]/[b]{outputSkippedFrames}[/b]\n" \
	+ "WS Incoming/Outgoing: [b]{webSocketSessionIncomingMessages}[/b]/[b]{webSocketSessionOutgoingMessages}[/b]\n"

var godot_stats_template = "" \
	+ "Active FPS: [b]{fps}[/b]\n" \
	+ "Frame Time: [b]{frameTime}[/b]\n" \
	+ "Video Memory Used: [b]{videoMemoryUsed}[/b]\n" \
	+ "Audio Latency: [b]{audioLatency}[/b]\n"

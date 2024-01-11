extends Node
class_name Templates

# region STATS

static var obs_stats_template = "" \
	+ "Active FPS: [b]{activeFps}[/b]\n" \
	+ "CPU Usage: [b]{cpuUsage}%[/b]\n" \
	+ "Memory Usage: [b]{memoryUsage} MB[/b]\n" \
	+ "Disk Space: [b]{availableDiskSpace} GB[/b]\n" \
	+ "Frame Render Time: [b]{averageFrameRenderTime} ms[/b]\n" \
	+ "Rendered Skipped: [b]{renderSkippedFrames}[/b]\n" \
	+ "Total Skipped: [b]{outputSkippedFrames}[/b]\n" \
	+ "WS In/Out: [b]{webSocketSessionIncomingMessages}[/b]/[b]{webSocketSessionOutgoingMessages}[/b]\n"

static var godot_stats_template = "" \
	+ "Active FPS: [b]{fps}[/b]\n" \
	+ "Frame Time: [b]{frameTime} s[/b]\n" \
	+ "VRAM Used: [b]{videoMemoryUsed} MB[/b]\n" \
	+ "Audio Latency: [b]{audioLatency} ms[/b]\n" \
	+ "Audio Comp: [b]{audioCompensation} ms[/b]\n"

static var backend_stats_template = "" \
	+ "WS In/Out: [b]{0}[/b]/[b]{1}[/b]\n"

static func format_obs_stats(res: Dictionary) -> String:
	var stats := {
		"activeFps": snapped(res.activeFps, 0),
		"cpuUsage": snapped(res.cpuUsage, 0.001),
		"memoryUsage": snapped(res.memoryUsage, 0.1),
		"availableDiskSpace": snapped(res.availableDiskSpace / 1024, 0.1),
		"averageFrameRenderTime": snapped(res.averageFrameRenderTime, 0.1),
		"renderTotalFrames": res.renderTotalFrames,
		"renderSkippedFrames": res.renderSkippedFrames,
		"outputTotalFrames": res.outputTotalFrames,
		"outputSkippedFrames": res.outputSkippedFrames,
		"webSocketSessionIncomingMessages": res.webSocketSessionIncomingMessages,
		"webSocketSessionOutgoingMessages": res.webSocketSessionOutgoingMessages,
	}

	return obs_stats_template.format(stats)

static func format_godot_stats() -> String:
	var stats := {
		"fps": _perf_mon("TIME_FPS"),
		"frameTime": snapped(_perf_mon("TIME_PROCESS"), 0.0001),
		"videoMemoryUsed": snapped(_perf_mon("RENDER_VIDEO_MEM_USED") / 1024 / 1000, 0.01),
		"audioLatency": snapped(_perf_mon("AUDIO_OUTPUT_LATENCY"), 0.0001),
		"audioCompensation": snapped(Globals.get_audio_compensation(), 0.0001)
	}

	return godot_stats_template.format(stats)


static func format_backend_stats(res: Array) -> String:
	return backend_stats_template.format(res)

static func _perf_mon(monitor: String) -> Variant:
	return Performance.get_monitor(Performance[monitor])

# endregion

# region NODES

static var filter_node_name := "Filter_%s_%s"
static var scene_node_name := "Scene_%s"

# endregion

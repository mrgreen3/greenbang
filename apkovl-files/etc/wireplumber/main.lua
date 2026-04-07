-- WirePlumber main configuration file for GreenBang
-- Minimal, sensible defaults for ALSA audio

-- Load default modules
load_module("standard-event-source")
load_module("si-standard-node-factory")
load_module("si-node")
load_module("si-audio-softdsp-endpoint")
load_module("si-monitor")

-- PipeWire audio configuration
load_module("pw-alsa")
load_module("pw-alsa-seq")

-- Policy and routing
load_module("si-simple-node-endpoint")

-- Session management
load_module("session-item")
load_module("default-nodes-api")
load_module("default-profile")

-- Export configuration
load_module("export-core")

-- Optional: Load custom rules if they exist
load_config("wireplumber/rules.d")

-- Audio routing rules for ALSA devices
-- Auto-routes standard ALSA devices

-- Speaker/default output routing
rules = {
  {
    matches = {
      {
        { "node.name", "matches", "alsa_output*" },
      },
    },
    apply_properties = {
      ["node.target.object"] = "auto",
      ["audio.rate"] = 48000,
      ["audio.channels"] = 2,
    },
  },

  -- Microphone/input device routing
  {
    matches = {
      {
        { "node.name", "matches", "alsa_input*" },
      },
    },
    apply_properties = {
      ["node.target.object"] = "auto",
      ["audio.rate"] = 48000,
      ["audio.channels"] = 2,
    },
  },
}

---Play dfpwm files

local dfpwm = require("cc.audio.dfpwm")
local speaker = peripheral.find("speaker")
---@cast speaker ccTweaked.peripherals.Speaker

local decoder = dfpwm.make_decoder()
for chunk in io.lines("music/157_2.dfpwn", 16 * 1024) do
    local buffer = decoder(chunk)

    while not speaker.playAudio(buffer) do
        os.pullEvent("speaker_audio_empty")
    end
end

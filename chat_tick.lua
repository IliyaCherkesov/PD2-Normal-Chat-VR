if not _G.IS_VR or not ChatGui then
    return
end

local TAG = "[PD2 VR Normal Chat] "

local function dlog(message)
    if log then
        log(TAG .. tostring(message))
    end
end

local function reset_input(self)
    local input_text = self._input_panel:child("input_text")

    input_text:set_text("")
    input_text:set_selection(0, 0)

    self._pd2vr_last_preview = ""
    self._pd2vr_last_cursor = 0

    self:update_caret()
end

dlog("ChatGui integration loaded")

function ChatGui:_on_focus()
    if not self._enabled or self._focus then
        return
    end

    self:start_hud_blur()

    local output_panel = self._panel:child("output_panel")

    output_panel:stop()
    output_panel:animate(callback(self, self, "_animate_show_component"), output_panel:alpha())

    self._input_panel:stop()
    self._input_panel:animate(callback(self, self, "_animate_show_input"))

    self._focus = true

    self._input_panel:child("focus_indicator"):set_color(Color(0, 0, 0):with_alpha(0.2))

    self._ws:connect_keyboard(Input:keyboard())

    --------------------------------------------------------
    -- Native SteamVR keyboard
    --------------------------------------------------------

    local B = _G.PD2VRChatBuffer

    if B then
        -- bridge.lua uses this instance to mirror the native
        -- keyboard buffer into ChatGui while typing.
        B.chat_gui_instance = self

        self._pd2vr_last_preview = nil
        self._pd2vr_last_cursor = nil
    end

    local function native_submit(submitted, submitted_text)
        -- Remove any character that may have leaked through the
        -- legacy PAYDAY / SteamVR keyboard path.
        reset_input(self)

        if not submitted then
            return
        end

        submitted_text = submitted_text or ""

        if submitted_text:match("^%s*$") then
            reset_input(self)
            return
        end

        self:enter_text(nil, submitted_text)
        self:enter_key_callback()

        -- Restore a clean field after PAYDAY moves the caret.
        reset_input(self)
    end

    local opened = B and B.open_direct_chat and
                       B.open_direct_chat("ChatGui:_on_focus", native_submit, "PAYDAY 2 Chat", 60, "")

    if not opened then
        dlog("Native keyboard unavailable; using vanilla fallback")
        Input:keyboard():show()
    end

    --------------------------------------------------------
    -- Original ChatGui focus setup
    --------------------------------------------------------

    self._input_panel:key_press(callback(self, self, "key_press"))

    self._input_panel:key_release(callback(self, self, "key_release"))

    self._enter_text_set = false

    self._input_panel:child("input_bg"):animate(callback(self, self, "_animate_input_bg"))

    self:set_layer(tweak_data.gui.CRIMENET_CHAT_LAYER)
    self:update_caret()
end

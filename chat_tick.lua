if not _G.IS_VR or not ChatGui then
    return
end

local function dlog(s)
    if log then
        log("[PD2 VR Chat Buffer v1.5] " .. tostring(s))
    end
end

dlog("chat_tick loaded; replacing ChatGui:_on_focus")

function ChatGui:_on_focus()
    if not self._enabled then
        return
    end

    if self._focus then
        return
    end

    self:start_hud_blur()

    local output_panel = self._panel:child("output_panel")

    output_panel:stop()
    output_panel:animate(
        callback(self, self, "_animate_show_component"),
        output_panel:alpha()
    )

    self._input_panel:stop()
    self._input_panel:animate(
        callback(self, self, "_animate_show_input")
    )

    self._focus = true

    self._input_panel:child("focus_indicator"):set_color(
        Color(0, 0, 0):with_alpha(0.2)
    )

    self._ws:connect_keyboard(Input:keyboard())

    local B = _G.PD2VRChatBuffer

    if B then
    B.chat_gui_instance = self

    self._pd2vr_last_preview = nil
    self._pd2vr_last_cursor = nil
end

    ------------------------------------------------------------
    -- Direct ChatGui submit path
    ------------------------------------------------------------

    local function native_submit(submitted, submitted_text)
    dlog(
    "ChatGui native submit"
    .. " submitted=" .. tostring(submitted)
    .. " text=[" .. tostring(submitted_text) .. "]"
)

    local input_text =
        self._input_panel:child("input_text")

   local function reset_input()
    input_text:set_text("")
    input_text:set_selection(0, 0)

    self._pd2vr_last_preview = ""
    self._pd2vr_last_cursor = 0

    self:update_caret()
end

    -- Очень важно:
    -- PAYDAY всё ещё может успеть положить последний символ
    -- SteamVR ввода в своё поле. Именно это дало twrist.
    reset_input()

    if not submitted then
        return
    end

    submitted_text =
        submitted_text or ""
    
    if submitted_text:match("^%s*$") then
    reset_input()
    return
end

    self:enter_text(
        nil,
        submitted_text
    )

    self:enter_key_callback()

    -- enter_text передвинул selection/caret в конец строки,
    -- поэтому после отправки возвращаем пустое поле в нулевую позицию.
    reset_input()
end

    local opened =
        B
        and B.open_direct_chat
        and B.open_direct_chat(
            "ChatGui:_on_focus",
            native_submit,
            "PAYDAY 2 Chat",
            60,
            ""
        )

    dlog(
        "ChatGui:_on_focus native opened="
        .. tostring(opened)
    )

    ------------------------------------------------------------
    -- Vanilla fallback
    ------------------------------------------------------------

    if not opened then
        Input:keyboard():show()

        dlog(
            "ChatGui:_on_focus fell back to vanilla keyboard"
        )
    end

    ------------------------------------------------------------
    -- Original ChatGui focus setup
    ------------------------------------------------------------

    self._input_panel:key_press(
        callback(self, self, "key_press")
    )

    self._input_panel:key_release(
        callback(self, self, "key_release")
    )

    self._enter_text_set = false

    self._input_panel:child("input_bg"):animate(
        callback(self, self, "_animate_input_bg")
    )

    self:set_layer(tweak_data.gui.CRIMENET_CHAT_LAYER)
    self:update_caret()
end

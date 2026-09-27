if not _G.IS_VR or not HUDChat then
    return
end

local function dlog(s)
    if log then
        log(
            "[PD2 VR Chat Buffer v1.5] "
            .. tostring(s)
        )
    end
end

dlog(
    "hud_tick loaded; replacing HUDChat:_on_focus"
)


function HUDChat:_on_focus()
    if self._focus then
        return
    end

    local output_panel =
        self._panel:child("output_panel")

    output_panel:stop()
    output_panel:animate(
        callback(
            self,
            self,
            "_animate_show_output"
        ),
        output_panel:alpha()
    )

    self._input_panel:stop()
    self._input_panel:animate(
        callback(
            self,
            self,
            "_animate_show_component"
        )
    )

    self._focus = true

    self._input_panel
        :child("focus_indicator")
        :set_color(
            Color(0.8, 1, 0.8)
                :with_alpha(0.2)
        )

    self._ws:connect_keyboard(
        Input:keyboard()
    )

    --------------------------------------------------------
    -- Native SteamVR keyboard
    --------------------------------------------------------

    local B = _G.PD2VRChatBuffer

local input_panel =
    self._input_panel

dlog(
    "HUDChat geometry"
    .. " panel=" .. tostring(self._panel:w())
    .. "x" .. tostring(self._panel:h())
    .. " output x=" .. tostring(output_panel:x())
    .. " y=" .. tostring(output_panel:y())
    .. " w=" .. tostring(output_panel:w())
    .. " h=" .. tostring(output_panel:h())
    .. " input x=" .. tostring(input_panel:x())
    .. " y=" .. tostring(input_panel:y())
    .. " w=" .. tostring(input_panel:w())
    .. " h=" .. tostring(input_panel:h())
)   

local last_preview = ""

    local function native_submit(submitted, submitted_text)
    dlog(
    "HUDChat native submit"
    .. " submitted=" .. tostring(submitted)
    .. " text=[" .. tostring(submitted_text) .. "]"
)

    local input_text =
        self._input_panel:child("input_text")

    local function reset_input()
        input_text:set_text("")
        input_text:set_selection(0, 0)

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
            "HUDChat:_on_focus",
            native_submit,
            "PAYDAY 2 Chat",
            60,
            ""
        )

    dlog(
        "HUDChat:_on_focus native opened="
        .. tostring(opened)
    )

    if not opened then
        Input:keyboard():show()

        dlog(
            "HUDChat:_on_focus fell back "
            .. "to vanilla keyboard"
        )
    end

    --------------------------------------------------------
    -- Original HUDChat focus setup
    --------------------------------------------------------

    self._input_panel:key_press(
        callback(
            self,
            self,
            "key_press"
        )
    )

    self._input_panel:key_release(
        callback(
            self,
            self,
            "key_release"
        )
    )

    self._enter_text_set = false

    self._input_panel
        :child("input_bg")
        :animate(
            callback(
                self,
                self,
                "_animate_input_bg"
            )
        )

    self:set_scroll_indicators(true)
    self:set_layer(1100)
    self:update_caret()
end
if not _G.IS_VR or not HUDManagerVR then
    return
end

local function dlog(s)
    if log then
        log("[PD2 VR Chat Buffer tablet preview] " .. tostring(s))
    end
end
dlog("tablet_preview.lua loaded")

local function ensure_preview(self)
    if not self then
        return false
    end

    if self._pd2vr_preview_panel then
        return true
    end

    if not self._tablet_ws then
        return false
    end

    local tablet_panel = self._tablet_ws:panel()

    if not tablet_panel then
        return false
    end

    local panel = tablet_panel:panel({
        name = "pd2vr_chat_preview_panel",
        x = 6,
        y = 5,
        w = tablet_panel:w() - 12,
        h = 28,
        layer = 2000,
        alpha = 1
    })

    panel:set_alpha(1)

    local background = panel:rect({
        name = "background",
        x = 0,
        y = 0,
        w = panel:w(),
        h = panel:h(),
        color = Color.black,
        alpha = 1,
        blend_mode = "normal",
        layer = 0
    })

    local text = panel:text({
        name = "preview_text",
        text = "",
        x = 7,
        y = 0,
        w = panel:w() - 14,
        h = panel:h(),
        font = tweak_data.hud.medium_font_noshadow,
        font_size = 17,
        color = Color.white,
        align = "left",
        vertical = "center",
        blend_mode = "normal",
        layer = 1
    })

    panel:hide()

    self._pd2vr_preview_panel = panel
    self._pd2vr_preview_text = text
    self._pd2vr_last_preview = nil
    self._pd2vr_last_cursor = nil

    dlog("tablet preview created" .. " root=" .. tostring(tablet_panel:w()) .. "x" .. tostring(tablet_panel:h()) ..
             " preview=" .. tostring(panel:w()) .. "x" .. tostring(panel:h()))

    return true
end
------------------------------------------------------------
-- Create preview box after VR Plus creates the tablet GUI.
------------------------------------------------------------

Hooks:PostHook(HUDManagerVR, "_init_tablet_gui", "PD2VRChatBuffer_CreateTabletPreview", function(self)
    ensure_preview(self)
end)

local function utf8_byte_offset(text, char_index)
    char_index = math.max(0, tonumber(char_index) or 0)

    if char_index == 0 then
        return 1
    end

    local byte_index = 1
    local chars = 0
    local len = #text

    while byte_index <= len and chars < char_index do
        local c = string.byte(text, byte_index)

        if c < 0x80 then
            byte_index = byte_index + 1

        elseif c < 0xE0 then
            byte_index = byte_index + 2

        elseif c < 0xF0 then
            byte_index = byte_index + 3

        else
            byte_index = byte_index + 4
        end

        chars = chars + 1
    end

    return math.min(byte_index, len + 1)
end

local function text_with_caret(text, cursor)
    local byte_pos = utf8_byte_offset(text, cursor)

    return string.sub(text, 1, byte_pos - 1) .. "|" .. string.sub(text, byte_pos)
end

------------------------------------------------------------
-- Update preview every gameplay frame.
------------------------------------------------------------

if not _G.PD2VRChatBuffer_TabletPreviewHooked then
    _G.PD2VRChatBuffer_TabletPreviewHooked = true

    Hooks:Add("GameSetupUpdate", "PD2VRChatBuffer_TabletPreviewUpdate", function(t, dt)

        local B = _G.PD2VRChatBuffer

        if not B or not B.peek then
            return
        end

        local hud = managers and managers.hud

        if not hud then
            return
        end

        if not ensure_preview(hud) then
            return
        end

        local panel = hud._pd2vr_preview_panel

        local text_obj = hud._pd2vr_preview_text

        if not panel or not text_obj then
            return
        end

        if B.active_source ~= "HUDChat:_on_focus" then
            if panel:visible() then
                panel:hide()
            end

            hud._pd2vr_last_preview = nil
            hud._pd2vr_last_cursor = nil

            return
        end

        local preview, cursor = B.peek()

        preview = preview or ""

        cursor = tonumber(cursor) or 0

        ----------------------------------------------------
        -- Nothing is being typed.
        ----------------------------------------------------

        if preview == "" then
            hud._pd2vr_last_preview = ""
            hud._pd2vr_last_cursor = 0

            text_obj:set_text("|")

            if not panel:visible() then
                panel:show()
            end

            return
        end

        ----------------------------------------------------
        -- No change.
        ----------------------------------------------------

        if preview == hud._pd2vr_last_preview and cursor == hud._pd2vr_last_cursor then

            return
        end

        hud._pd2vr_last_preview = preview
        hud._pd2vr_last_cursor = cursor

        ----------------------------------------------------
        -- Update text.
        ----------------------------------------------------

        text_obj:set_text(text_with_caret(preview, cursor))

        if not panel:visible() then
            panel:show()
        end
    end)
end

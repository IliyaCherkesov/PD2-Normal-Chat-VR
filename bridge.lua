local TAG = "[PD2 VR Chat Buffer v1.4] "

local function dlog(s)
    if log then
        log(TAG .. tostring(s))
    end
end

local function safe(v)
    local ok, s = pcall(tostring, v)
    return ok and s or "<tostring failed>"
end

if not _G.IS_VR or not NetworkAccountSTEAM then
    return
end

PD2VRChatBuffer = PD2VRChatBuffer or {
    native = nil,

    active_account = nil,
    active_id = nil,
    active_submit = nil,
    active_source = nil,

    captured_account = nil,
    captured_id = nil,
    captured_clbk = nil,
    captured_params = nil
}

local B = PD2VRChatBuffer


------------------------------------------------------------
-- Native DLL
------------------------------------------------------------

if not B.native then
    local ok, native_or_err =
        blt.load_native(ModPath .. "pd2_vr_chat_buffer.dll")

    if not ok then
        dlog("ERROR loading native DLL: " .. safe(native_or_err))
        return
    end

    B.native = native_or_err
    dlog("native DLL loaded")
end


------------------------------------------------------------
-- Poll native keyboard
------------------------------------------------------------

function B.peek()
    if not B.native or not B.native.peek then
        return "", 0
    end

    local ok, text, cursor =
        pcall(B.native.peek)

    if not ok then
        return "", 0
    end

    text = text or ""
    cursor = tonumber(cursor)

    -- Совместимость со старой DLL,
    -- которая возвращала только текст.
    if cursor == nil then
        if utf8 and utf8.len then
            cursor = utf8.len(text) or 0
        else
            cursor = #text
        end
    end

    return text, cursor
end

------------------------------------------------------------
-- Frame-rate preview update
------------------------------------------------------------

local function update_chat_gui_preview()
    if B.active_source ~= "ChatGui:_on_focus" then
        return
    end

    local gui = B.chat_gui_instance

    if not gui
        or not gui._focus
        or not gui._input_panel then
        return
    end

    local preview, cursor =
        B.peek()

    if preview == gui._pd2vr_last_preview
        and cursor == gui._pd2vr_last_cursor then
        return
    end

    local ok, err =
        pcall(function()

            local input_text =
                gui._input_panel:child("input_text")

            input_text:set_text(preview)

            input_text:set_selection(
                cursor,
                cursor
            )

            gui._pd2vr_last_preview =
                preview

            gui._pd2vr_last_cursor =
                cursor

            gui:update_caret()
        end)

    if not ok then
        dlog(
            "ERROR updating ChatGui preview: "
            .. safe(err)
        )
    end
end


function B.frame_update()
    B.poll()
    update_chat_gui_preview()
end


if not B._frame_hooks_installed then
    B._frame_hooks_installed = true

    Hooks:Add(
        "GameSetupUpdate",
        "PD2VRChatBuffer_GameFrame",
        function(t, dt)
            B.frame_update()
        end
    )

    Hooks:Add(
        "MenuUpdate",
        "PD2VRChatBuffer_MenuFrame",
        function(t, dt)
            B.frame_update()
        end
    )

    dlog(
        "frame polling hooked through "
        .. "GameSetupUpdate/MenuUpdate"
    )
end

function B.poll()
    if not B.native then
        return
    end

    -- Nothing is waiting for a native keyboard result.
    if not B.active_submit
        and not B.active_account
        and not B.active_id then
        return
    end

    local state, text = B.native.poll()

    if state == "pending" then
        return
    end

    local submitted = state == "done"

    local submit_callback = B.active_submit
    local account = B.active_account
    local id = B.active_id
    local source = B.active_source

    -- Clear state BEFORE dispatching the callback.
    -- This prevents the callback from seeing the previous
    -- native session as still active.
    B.active_submit = nil
    B.active_account = nil
    B.active_id = nil
    B.active_source = nil

    dlog(
        "native result"
        .. " state=" .. safe(state)
        .. " text=[" .. safe(text) .. "]"
        .. " source=[" .. safe(source) .. "]"
        .. " id=[" .. safe(id) .. "]"
    )

    --------------------------------------------------------
    -- Direct callback path
    -- Used by HUDChat.
    --------------------------------------------------------

    if submit_callback then
        local ok, err = pcall(
            submit_callback,
            submitted,
            text or ""
        )

        if ok then
            dlog("direct submit callback dispatched")
        else
            dlog(
                "ERROR direct submit callback failed: "
                .. safe(err)
            )
        end

        return
    end

    --------------------------------------------------------
    -- Original NetworkAccount path
    -- Used by ChatGui.
    --------------------------------------------------------

    if account and account._on_gamepad_text_submitted then
        account:_on_gamepad_text_submitted(
            submitted,
            text or ""
        )

        dlog("_on_gamepad_text_submitted dispatched")
    else
        dlog(
            "ERROR: no submit callback and account has no "
            .. "_on_gamepad_text_submitted"
        )
    end
end


------------------------------------------------------------
-- ChatGui path
------------------------------------------------------------

function B.open_captured_chat(source)
    if not B.native then
        dlog(
            "open from "
            .. safe(source)
            .. " failed: native missing"
        )

        return false
    end

    if B.active_submit or B.active_account or B.active_id then
        dlog(
            "open from "
            .. safe(source)
            .. " ignored: native already active"
        )

        return true
    end

    if not B.captured_account
        or not B.captured_id
        or not B.captured_clbk then

        dlog(
            "open from "
            .. safe(source)
            .. " failed: captured listener incomplete"
        )

        return false
    end

    local account = B.captured_account
    local id = B.captured_id

    account._gamepad_text_listeners =
        account._gamepad_text_listeners or {}

    account._gamepad_text_listeners[id] =
        B.captured_clbk

    dlog(
        "registered captured callback for id=["
        .. safe(id)
        .. "]"
    )

    local params = B.captured_params or {}

    local description =
        safe(params[3] or "PAYDAY 2 Chat")

    if description:find("^ERROR:") then
        description = "PAYDAY 2 Chat"
    end

    local max_chars =
        tonumber(params[4]) or 60

    local existing =
        safe(params[5] or "")

    local started, err =
        B.native.start(
            description,
            max_chars,
            existing
        )

    dlog(
        "open from "
        .. safe(source)
        .. " -> native.start="
        .. safe(started)
        .. " err=["
        .. safe(err)
        .. "] id=["
        .. safe(id)
        .. "]"
    )

    if not started then
        account._gamepad_text_listeners[id] = nil
        return false
    end

    B.active_account = account
    B.active_id = id
    B.active_submit = nil
    B.active_source = source

    return true
end


------------------------------------------------------------
-- Direct callback path
-- Used by HUDChat.
------------------------------------------------------------

function B.open_direct_chat(
    source,
    submit_callback,
    description,
    max_chars,
    existing
)
    if not B.native then
        dlog(
            "direct open from "
            .. safe(source)
            .. " failed: native missing"
        )

        return false
    end

    if type(submit_callback) ~= "function" then
        dlog(
            "direct open from "
            .. safe(source)
            .. " failed: callback missing"
        )

        return false
    end

    if B.active_submit or B.active_account or B.active_id then
        dlog(
            "direct open from "
            .. safe(source)
            .. " ignored: native already active"
        )

        return true
    end

    description = description or "PAYDAY 2 Chat"
    max_chars = tonumber(max_chars) or 60
    existing = existing or ""

    local started, err =
        B.native.start(
            description,
            max_chars,
            existing
        )

    dlog(
        "direct open from "
        .. safe(source)
        .. " -> native.start="
        .. safe(started)
        .. " err=["
        .. safe(err)
        .. "]"
    )

    if not started then
        return false
    end

    B.active_submit = submit_callback
    B.active_account = nil
    B.active_id = nil
    B.active_source = source

    return true
end


------------------------------------------------------------
-- Capture ChatGui's gamepad callback
------------------------------------------------------------

local vanilla_show =
    NetworkAccountSTEAM.show_gamepad_text_input

function NetworkAccountSTEAM:show_gamepad_text_input(
    id,
    clbk,
    params
)
    local result =
        vanilla_show(
            self,
            id,
            clbk,
            params
        )

    B.captured_account = self
    B.captured_id = id
    B.captured_clbk = clbk
    B.captured_params = params

    dlog(
        "captured chat callback id=["
        .. safe(id)
        .. "] vanilla_result=["
        .. safe(result)
        .. "]"
    )

    return result
end


dlog("Lua bridge initialized")
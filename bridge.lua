if not _G.IS_VR or not NetworkAccountSTEAM then
    return
end

local TAG = "[PD2 VR Normal Chat] "

local function dlog(message)
    if log then
        log(TAG .. tostring(message))
    end
end

local function safe(value)
    local ok, result = pcall(tostring, value)

    if ok then
        return result
    end

    return "<tostring failed>"
end

------------------------------------------------------------
-- Shared bridge state
------------------------------------------------------------

PD2VRChatBuffer = PD2VRChatBuffer or {
    native = nil,

    active_account = nil,
    active_id = nil,
    active_submit = nil,
    active_source = nil,

    captured_account = nil,
    captured_id = nil,
    captured_clbk = nil,
    captured_params = nil,

    chat_gui_instance = nil
}

local B = PD2VRChatBuffer

local function native_session_active()
    return B.active_submit ~= nil or B.active_account ~= nil or B.active_id ~= nil
end

local function clear_active_session()
    B.active_submit = nil
    B.active_account = nil
    B.active_id = nil
    B.active_source = nil
end

------------------------------------------------------------
-- Native DLL
------------------------------------------------------------

if not B.native then
    local ok, native_or_error = blt.load_native(ModPath .. "pd2_vr_chat_buffer.dll")

    if not ok then
        dlog("Failed to load native DLL: " .. safe(native_or_error))

        return
    end

    B.native = native_or_error

    dlog("Native OpenVR bridge loaded")
end

------------------------------------------------------------
-- Current native keyboard buffer
------------------------------------------------------------

function B.peek()
    if not B.native or not B.native.peek then
        return "", 0
    end

    local ok, text, cursor = pcall(B.native.peek)

    if not ok then
        return "", 0
    end

    text = text or ""
    cursor = tonumber(cursor)

    -- Older versions of the native DLL returned only the text.
    -- Fall back to the end of the string in that case.
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
-- Native keyboard result polling
------------------------------------------------------------

function B.poll()
    if not B.native or not native_session_active() then
        return
    end

    local ok, state, text = pcall(B.native.poll)

    if not ok then
        dlog("Native poll failed: " .. safe(state))

        clear_active_session()
        return
    end

    if state == "pending" then
        return
    end

    local submitted = state == "done"

    local submit_callback = B.active_submit

    local account = B.active_account

    local id = B.active_id

    -- Clear the current native session before invoking PAYDAY callbacks.
    -- A callback may immediately open another keyboard session.
    clear_active_session()

    --------------------------------------------------------
    -- Direct callback path
    -- Used by HUDChat and ChatGui.
    --------------------------------------------------------

    if submit_callback then
        local callback_ok, callback_error = pcall(submit_callback, submitted, text or "")

        if not callback_ok then
            dlog("Submit callback failed: " .. safe(callback_error))
        end

        return
    end

    --------------------------------------------------------
    -- Legacy NetworkAccount path
    --------------------------------------------------------

    if account and account._on_gamepad_text_submitted then

        account:_on_gamepad_text_submitted(submitted, text or "")

        return
    end

    dlog("Native keyboard finished without a valid submit target")
end

------------------------------------------------------------
-- ChatGui live preview
------------------------------------------------------------

local function update_chat_gui_preview()
    if B.active_source ~= "ChatGui:_on_focus" then
        return
    end

    local gui = B.chat_gui_instance

    if not gui or not gui._focus or not gui._input_panel then
        return
    end

    local preview, cursor = B.peek()

    if preview == gui._pd2vr_last_preview and cursor == gui._pd2vr_last_cursor then
        return
    end

    local ok, error_message = pcall(function()
        local input_text = gui._input_panel:child("input_text")

        input_text:set_text(preview)

        input_text:set_selection(cursor, cursor)

        gui._pd2vr_last_preview = preview

        gui._pd2vr_last_cursor = cursor

        gui:update_caret()
    end)

    if not ok then
        dlog("Failed to update ChatGui preview: " .. safe(error_message))
    end
end

------------------------------------------------------------
-- Per-frame bridge update
------------------------------------------------------------

function B.frame_update()
    B.poll()
    update_chat_gui_preview()
end

if not B._frame_hooks_installed then
    B._frame_hooks_installed = true

    Hooks:Add("GameSetupUpdate", "PD2VRNormalChat_GameFrame", function(t, dt)
        B.frame_update()
    end)

    Hooks:Add("MenuUpdate", "PD2VRNormalChat_MenuFrame", function(t, dt)
        B.frame_update()
    end)
end

------------------------------------------------------------
-- Direct keyboard session
------------------------------------------------------------

function B.open_direct_chat(source, submit_callback, description, max_chars, existing)
    if not B.native then
        return false
    end

    if type(submit_callback) ~= "function" then
        dlog("Cannot open native keyboard: submit callback missing")

        return false
    end

    -- A keyboard session is already running.
    -- Treat this as success so PAYDAY does not open the legacy keyboard.
    if native_session_active() then
        return true
    end

    description = description or "PAYDAY 2 Chat"

    max_chars = tonumber(max_chars) or 60

    existing = existing or ""

    local started, error_message = B.native.start(description, max_chars, existing)

    if not started then
        dlog("Failed to open native keyboard: " .. safe(error_message))

        return false
    end

    B.active_submit = submit_callback
    B.active_account = nil
    B.active_id = nil
    B.active_source = source

    return true
end

------------------------------------------------------------
-- Legacy captured NetworkAccount path
--
-- Retained for compatibility with PAYDAY code paths that still
-- rely on show_gamepad_text_input() instead of direct callbacks.
------------------------------------------------------------

function B.open_captured_chat(source)
    if not B.native then
        return false
    end

    if native_session_active() then
        return true
    end

    if not B.captured_account or not B.captured_id or not B.captured_clbk then
        return false
    end

    local account = B.captured_account

    local id = B.captured_id

    account._gamepad_text_listeners = account._gamepad_text_listeners or {}

    account._gamepad_text_listeners[id] = B.captured_clbk

    local params = B.captured_params or {}

    local description = params[3] or "PAYDAY 2 Chat"

    local max_chars = tonumber(params[4]) or 60

    local existing = params[5] or ""

    local started, error_message = B.native.start(description, max_chars, existing)

    if not started then
        account._gamepad_text_listeners[id] = nil

        dlog("Failed to open captured native keyboard: " .. safe(error_message))

        return false
    end

    B.active_account = account
    B.active_id = id
    B.active_submit = nil
    B.active_source = source

    return true
end

------------------------------------------------------------
-- Capture PAYDAY's gamepad text listener
------------------------------------------------------------

local vanilla_show_gamepad_text_input = NetworkAccountSTEAM.show_gamepad_text_input

function NetworkAccountSTEAM:show_gamepad_text_input(id, clbk, params)
    local result = vanilla_show_gamepad_text_input(self, id, clbk, params)

    B.captured_account = self
    B.captured_id = id
    B.captured_clbk = clbk
    B.captured_params = params

    return result
end

dlog("Lua bridge initialized")

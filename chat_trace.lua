local TAG = "[PD2 VR CHAT TRACE] "

local function tlog(msg)
    if log then
        log(TAG .. tostring(msg))
    end
end

local function s(v)
    local ok, out = pcall(tostring, v)
    return ok and out or "<tostring failed>"
end

tlog("chat_trace.lua loaded")

if ChatManager then
    if ChatManager.send_message then
        Hooks:PreHook(
            ChatManager,
            "send_message",
            "PD2VRTrace_ChatManager_send_message",
            function(self, channel_id, sender, message)
                tlog(
                    "ChatManager:send_message"
                    .. " channel=[" .. s(channel_id) .. "]"
                    .. " sender=[" .. s(sender) .. "]"
                    .. " message=[" .. s(message) .. "]"
                )
            end
        )
    end

    if ChatManager.receive_message_by_peer then
        Hooks:PreHook(
            ChatManager,
            "receive_message_by_peer",
            "PD2VRTrace_receive_message_by_peer",
            function(self, channel_id, peer, message)
                tlog(
                    "ChatManager:receive_message_by_peer"
                    .. " channel=[" .. s(channel_id) .. "]"
                    .. " peer=[" .. s(peer and peer:name()) .. "]"
                    .. " message=[" .. s(message) .. "]"
                )
            end
        )
    end

    if ChatManager.receive_message_by_name then
        Hooks:PreHook(
            ChatManager,
            "receive_message_by_name",
            "PD2VRTrace_receive_message_by_name",
            function(self, channel_id, name, message)
                tlog(
                    "ChatManager:receive_message_by_name"
                    .. " channel=[" .. s(channel_id) .. "]"
                    .. " name=[" .. s(name) .. "]"
                    .. " message=[" .. s(message) .. "]"
                )
            end
        )
    end

    if ChatManager._receive_message then
        Hooks:PreHook(
            ChatManager,
            "_receive_message",
            "PD2VRTrace__receive_message",
            function(self, channel_id, name, message, color, icon)
                local receivers = self._receivers
                    and self._receivers[channel_id]

                tlog(
                    "ChatManager:_receive_message"
                    .. " channel=[" .. s(channel_id) .. "]"
                    .. " name=[" .. s(name) .. "]"
                    .. " message=[" .. s(message) .. "]"
                    .. " receivers=[" .. s(receivers and #receivers or 0) .. "]"
                )

                if receivers then
                    for i, receiver in ipairs(receivers) do
                        tlog(
                            "  receiver #" .. i
                            .. " obj=[" .. s(receiver) .. "]"
                            .. " class=[" .. s(receiver and receiver.__class) .. "]"
                        )
                    end
                end
            end
        )
    end
end

if ChatGui and ChatGui.receive_message then
    Hooks:PreHook(
        ChatGui,
        "receive_message",
        "PD2VRTrace_ChatGui_receive_message",
        function(self, name, message, color, icon)
            tlog(
                "ChatGui:receive_message"
                .. " self=[" .. s(self) .. "]"
                .. " name=[" .. s(name) .. "]"
                .. " message=[" .. s(message) .. "]"
            )
        end
    )
end

if HUDChat and HUDChat.receive_message then
    Hooks:PreHook(
        HUDChat,
        "receive_message",
        "PD2VRTrace_HUDChat_receive_message",
        function(self, name, message, color, icon)
            tlog(
                "HUDChat:receive_message"
                .. " self=[" .. s(self) .. "]"
                .. " name=[" .. s(name) .. "]"
                .. " message=[" .. s(message) .. "]"
            )
        end
    )
end
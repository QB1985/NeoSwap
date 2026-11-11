-- status.lua : the one-line message at the foot of the window (and, for problems, in chat too)
local chat = require('chat');

local status = { msg = '', kind = 'ok', untilt = 0 };

-- kind: 'ok', 'warn', 'err', 'info'
function status.set(msg, kind, secs, to_chat)
    status.msg = msg or '';
    status.kind = kind or 'ok';
    status.untilt = os.clock() + (secs or 5);
    if to_chat then
        local f = (kind == 'err' or kind == 'warn') and chat.error or (kind == 'ok' and chat.success or chat.message);
        print(chat.header('NeoSwap') .. f(msg));
    end
end

function status.get()
    if status.msg == '' or os.clock() > status.untilt then return nil; end
    return status.msg, status.kind;
end

function status.clear() status.msg = ''; end

return status;

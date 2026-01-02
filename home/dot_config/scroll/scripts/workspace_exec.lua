-- workspace_exec.lua <name> <commands>
local args, state = ...

local scroll = require("scroll")

local function on_create_ws(workspace, _)
    local name = scroll.workspace_get_name(workspace)
    if name == args[1] then
        local cmd = table.concat(args, " ", 2)
        scroll.command(workspace, cmd)
    end
end

scroll.add_callback("workspace_create", on_create_ws, nil)

local args, state = ...

local scroll = require("scroll")

local target_class = "steam_app_infinitas"

local function reject_fullscreen(view)
    if scroll.view_get_class(view) ~= target_class then
        return
    end

    local container = scroll.view_get_container(view)
    if container == nil or scroll.container_get_fullscreen_mode(container) == "none" then
        return
    end

    scroll.command(container, "fullscreen application enable; fullscreen disable")
end

local function on_ipc_view(view, change, _)
    if change == "fullscreen_mode" then
        reject_fullscreen(view)
    end
end

local function visit_container(container)
    for _, view in ipairs(scroll.container_get_views(container) or {}) do
        reject_fullscreen(view)
    end
    for _, child in ipairs(scroll.container_get_children(container) or {}) do
        visit_container(child)
    end
end

local function reconcile_existing_views()
    for _, output in ipairs(scroll.root_get_outputs() or {}) do
        for _, workspace in ipairs(scroll.output_get_workspaces(output) or {}) do
            for _, container in ipairs(scroll.workspace_get_tiling(workspace) or {}) do
                visit_container(container)
            end
            for _, container in ipairs(scroll.workspace_get_floating(workspace) or {}) do
                visit_container(container)
            end
        end
    end
end

local callback_key = "ipc_callback"
local callback_id = scroll.state_get_value(state, callback_key)
if callback_id ~= nil then
    scroll.remove_callback(callback_id)
end

scroll.state_set_value(state, callback_key, scroll.add_callback("ipc_view", on_ipc_view, nil))
reconcile_existing_views()

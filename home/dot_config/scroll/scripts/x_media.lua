local args, state = ...

local scroll = require("scroll")

local app_id = "chrome-x.com__-Default"
local media_marker = "⟦X media⟧ "
local media_mark = "x-media"
local auto_float_mark = "x-media-auto-float"

local function has_mark(container, expected)
    if container == nil then
        return false
    end
    for _, mark in ipairs(scroll.container_get_marks(container) or {}) do
        if mark == expected then
            return true
        end
    end
    return false
end

local function sync_view(view)
    if scroll.view_get_app_id(view) ~= app_id then
        return
    end

    local container = scroll.view_get_container(view)
    if container == nil then
        return
    end
    local title = scroll.view_get_title(view) or ""
    local media_active = string.sub(title, 1, #media_marker) == media_marker
    local marked_media = has_mark(container, media_mark)
    local auto_floated = has_mark(container, auto_float_mark)

    if media_active then
        if not marked_media then
            scroll.command(container, "mark --add " .. media_mark)
        end
        if not scroll.container_get_floating(container) and not auto_floated then
            scroll.command(container, "mark --add " .. auto_float_mark)
            scroll.command(container, "floating enable")
        end
        return
    end

    if auto_floated then
        scroll.command(container, "floating disable")
        container = scroll.view_get_container(view)
        scroll.command(container, "unmark " .. auto_float_mark)
    end
    if marked_media then
        container = scroll.view_get_container(view)
        scroll.command(container, "unmark " .. media_mark)
    end
end

local function on_ipc_view(view, change, _)
    if change == "title" then
        sync_view(view)
    end
end

local function on_view_map(view, _)
    sync_view(view)
end

local function visit_container(container)
    for _, view in ipairs(scroll.container_get_views(container) or {}) do
        sync_view(view)
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

for _, key in ipairs({ "ipc_callback", "map_callback" }) do
    local callback_id = scroll.state_get_value(state, key)
    if callback_id ~= nil then
        scroll.remove_callback(callback_id)
    end
end

scroll.state_set_value(state, "ipc_callback", scroll.add_callback("ipc_view", on_ipc_view, nil))
scroll.state_set_value(state, "map_callback", scroll.add_callback("view_map", on_view_map, nil))
reconcile_existing_views()

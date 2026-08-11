local args, state = ...

local scroll = require("scroll")

local app_id = "chrome-x.com__-Default"
local media_marker = "⟦X media⟧ "
local media_mark = "x-media"
local auto_float_mark = "x-media-auto-float"
local origin_workspaces = scroll.state_get_value(state, "origin_workspaces") or {}

local function container_key(container)
    return tostring(scroll.container_get_id(container))
end

local function remember_workspace(container)
    local key = container_key(container)
    if origin_workspaces[key] == nil then
        local workspace = scroll.container_get_workspace(container)
        origin_workspaces[key] = scroll.workspace_get_name(workspace)
        scroll.state_set_value(state, "origin_workspaces", origin_workspaces)
    end
end

local function media_geometry(container)
    local workspace = scroll.container_get_workspace(container)
    local width = scroll.workspace_get_width(workspace)
    local height = scroll.workspace_get_height(workspace)
    local split = scroll.workspace_get_split(workspace) or {}
    local sibling = split.sibling

    if sibling ~= nil then
        local sibling_width = scroll.workspace_get_width(sibling)
        local sibling_height = scroll.workspace_get_height(sibling)
        local gap = split.gap or 0

        if split.split == "left" or split.split == "right" then
            width = width + sibling_width + gap
        elseif split.split == "top" or split.split == "bottom" then
            height = height + sibling_height + gap
        end
    end

    return width, math.floor(height / 2)
end

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
        if auto_floated then
            remember_workspace(container)
        end
        if not scroll.container_get_floating(container) and not auto_floated then
            local width, height = media_geometry(container)
            remember_workspace(container)
            scroll.command(container, "mark --add " .. auto_float_mark)
            scroll.command(container, "floating enable")
            scroll.command(container, string.format(
                "resize set width %d px height %d px",
                width,
                height
            ))
        end
        return
    end

    if auto_floated then
        local key = container_key(container)
        local origin_workspace = origin_workspaces[key]
        if origin_workspace ~= nil then
            scroll.command(container, "move container to workspace " .. origin_workspace)
        end
        scroll.command(container, "floating disable")
        container = scroll.view_get_container(view)
        scroll.command(container, "set_size h 1; set_size v 1")
        scroll.command(container, "unmark " .. auto_float_mark)
        origin_workspaces[key] = nil
        scroll.state_set_value(state, "origin_workspaces", origin_workspaces)
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

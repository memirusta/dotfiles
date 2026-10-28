-- Workspaces 1-4 always exist (the old Waybar "persistent-workspaces" behaviour),
-- so the Caelestia workspace indicators are always visible.
for i = 1, 4 do
    hl.workspace_rule({ workspace = tostring(i), persistent = true })
end

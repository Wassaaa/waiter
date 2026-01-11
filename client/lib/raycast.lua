---@class RaycastLib
local Raycast = {}

local Controls = require 'client.lib.controls'

---Get ray origin and direction from screen inputs
---@return vector3 origin The world coordinates where the ray starts
---@return vector3 direction Normalized direction vector suitable for raycasting
function Raycast.FromScreen()
    -- Using native cursor controls (0.0 to 1.0 range)
    local x = GetControlNormal(0, Controls.CURSOR_X)
    local y = GetControlNormal(0, Controls.CURSOR_Y)

    -- GetWorldCoordFromScreenCoord returns start point (near clip) and direction helper
    local origin, direction = GetWorldCoordFromScreenCoord(x, y)
    return origin, direction
end

---Calculate intersection point of a ray with a horizontal plane at a given Z height
---@param origin vector3 Ray origin
---@param direction vector3 Ray direction
---@param planeZ number The target Z height of the plane
---@return vector3|nil hitPos The intersection point or nil if parallel/behind
function Raycast.IntersectPlane(origin, direction, planeZ)
    -- Ray Equation: P(t) = Origin + Direction * t
    -- Plane Equation: P.z = planeZ
    -- Solve for t: (Origin.z + Direction.z * t) = planeZ
    -- t = (planeZ - Origin.z) / Direction.z

    -- Avoid division by zero (parallel to plane)
    if math.abs(direction.z) < 0.001 then
        return nil
    end

    local t = (planeZ - origin.z) / direction.z

    -- If t < 0, the intersection is behind the ray origin
    if t < 0 then
        return nil
    end

    return origin + (direction * t)
end

return Raycast

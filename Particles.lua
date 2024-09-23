local imgui = require 'imgui'

local Particle = {}
Particle.__index = Particle

local function merge_tables(default, custom)
    local merged = {}
    for k, v in pairs(default) do merged[k] = v end
    if custom then
        for k, v in pairs(custom) do merged[k] = v end
    end
    return merged
end

function Particle:new(x, y, vx, vy, life, settings)
    return setmetatable({
        x = x or 0,
        y = y or 0,
        vx = vx or 0,
        vy = vy or 0,
        life = life or 100,
        settings = settings,
        size = settings.particle_size or 2,
        color = {table.unpack(settings.color or {1,1,1,1})},
        color_cycle = 0
    }, Particle)
end

function Particle:update(size, mouse_pos, particles)
    local settings = self.settings
    if settings.gravity ~= 0 then
        self.vy = self.vy + settings.gravity
    end
    if settings.magnetism ~= "none" then
        if settings.magnetism == "both" or settings.magnetism == "cursor" then
            if mouse_pos then
                local dx, dy = mouse_pos.x - self.x, mouse_pos.y - self.y
                local dist_sq = dx * dx + dy * dy
                if dist_sq < settings.magnetism_radius * settings.magnetism_radius and dist_sq > 0 then
                    local dist = math.sqrt(dist_sq)
                    local force = math.min(settings.magnetism_strength / dist_sq, 1000)
                    self.vx = self.vx + (force * dx) / dist
                    self.vy = self.vy + (force * dy) / dist
                end
            end
        end
        if settings.magnetism == "both" or settings.magnetism == "particles" then
            for _, other in ipairs(particles) do
                if other ~= self then
                    local dx, dy = other.x - self.x, other.y - self.y
                    local dist_sq = dx * dx + dy * dy
                    if dist_sq < settings.magnetism_radius * settings.magnetism_radius and dist_sq > 0 then
                        local dist = math.sqrt(dist_sq)
                        local force = math.min(settings.magnetism_strength / dist_sq, 1000)
                        self.vx = self.vx + (force * dx) / dist
                        self.vy = self.vy + (force * dy) / dist
                    end
                end
            end
        end
    end
    self.vx = (self.vx + (settings.wind or 0)) * (settings.friction or 0.99)
    self.vy = self.vy * (settings.friction or 0.99)
    local speed_sq = self.vx * self.vx + self.vy * self.vy
    local max_speed_sq = (settings.max_speed or 5.0) ^ 2
    if speed_sq > max_speed_sq then
        local speed = math.sqrt(speed_sq)
        self.vx = self.vx * (settings.max_speed / speed)
        self.vy = self.vy * (settings.max_speed / speed)
    end
    self.x = self.x + self.vx
    self.y = self.y + self.vy
    if not settings.infinite_life then
        self.life = self.life - 1
    end
    if self.x < 0 or self.x > size.x or self.y < 0 or self.y > size.y then
        if settings.boundary_behavior == "bounce" then
            if self.x < 0 or self.x > size.x then
                self.vx = -self.vx
                self.x = math.max(0, math.min(self.x, size.x))
            end
            if self.y < 0 or self.y > size.y then
                self.vy = -self.vy
                self.y = math.max(0, math.min(self.y, size.y))
            end
        else
            self:respawn(size)
        end
    end
    if not settings.infinite_life and self.life <= 0 then
        self:respawn(size)
    end
    speed_sq = self.vx * self.vx + self.vy * self.vy
    local min_speed_sq = (settings.min_speed or 0.5) ^ 2
    if speed_sq < min_speed_sq then
        local speed = math.sqrt(speed_sq)
        if speed > 0 then
            local scale = (settings.min_speed or 0.5) / speed
            self.vx = self.vx * scale
            self.vy = self.vy * scale
        else
            local angle = math.random() * 2 * math.pi
            self.vx = (settings.min_speed or 0.5) * math.cos(angle)
            self.vy = (settings.min_speed or 0.5) * math.sin(angle)
        end
    end
    if settings.color_animation == "rainbow" then
        self.color_cycle = (self.color_cycle + (settings.rainbow_speed or 0.005)) % 1
        self.color = {
            math.sin(2 * math.pi * self.color_cycle) * 0.5 + 0.5,
            math.sin(2 * math.pi * (self.color_cycle + 1/3)) * 0.5 + 0.5,
            math.sin(2 * math.pi * (self.color_cycle + 2/3)) * 0.5 + 0.5,
            1
        }
    elseif type(settings.color_animation) == "table" then
        local idx = (math.floor(self.color_cycle) % #settings.color_animation) + 1
        self.color = settings.color_animation[idx]
        self.color_cycle = self.color_cycle + 0.01
    end
end

function Particle:respawn(size)
    local settings = self.settings
    self.x = math.random(0, size.x)
    self.y = math.random(0, size.y)
    self.vx = math.random(settings.speed_range[1]*100, settings.speed_range[2]*100) / 100
    self.vy = math.random(settings.speed_range[1]*100, settings.speed_range[2]*100) / 100
    self.life = settings.infinite_life and math.huge or math.random(50, 150)
    self.size = settings.particle_size or 2
    self.color = {table.unpack(settings.color or {1,1,1,1})}
end

function Particle:draw(draw_list, win_pos, color, size_override)
    local radius = size_override or self.size
    draw_list:AddCircleFilled(imgui.ImVec2(win_pos.x + self.x, win_pos.y + self.y), radius, color)
end

local Particles = {}
Particles.__index = Particles

function Particles:new(settings)
    local default_settings = {
        max_particles = 100,
        gravity = 0.1,
        color = {1,1,1,1},
        line_color = {1,1,1,0.3},
        max_distance = 100,
        boundary_behavior = "respawn",
        infinite_life = false,
        magnetism = "none",
        magnetism_strength = 1000,
        magnetism_radius = 150,
        speed_range = { -1.0, 1.0 },
        min_speed = 0.5,
        max_speed = 5.0,
        color_animation = "none",
        line_color_animation = "none",
        rainbow_speed = 0.005,
        line_rainbow_speed = 0.005,
        line_thickness = 1,
        particle_size = 2,
        wind = 0,
        friction = 0.98,
        size = imgui.ImVec2(500,500)
    }
    settings = merge_tables(default_settings, settings)
    local obj = setmetatable({
        particles = {},
        max_particles = settings.max_particles,
        size = settings.size or imgui.ImVec2(500,500),
        settings = settings,
        color_cycle = settings.color_cycle or 0,
        line_color = {table.unpack(settings.line_color)},
        line_thickness = settings.line_thickness
    }, Particles)
    for i = 1, obj.max_particles do
        local p = Particle:new(0, 0, 0, 0, 0, obj.settings)
        p:respawn(obj.size)
        obj.particles[i] = p
    end
    return obj
end

function Particles:update(mouse_pos)
    local magnetism = self.settings.magnetism
    local particles = (magnetism == "particles" or magnetism == "both") and self.particles or nil
    for _, p in ipairs(self.particles) do
        p:update(self.size, mouse_pos, particles)
    end
    if self.settings.line_color_animation == "rainbow" then
        self.color_cycle = (self.color_cycle + (self.settings.line_rainbow_speed or 0.005)) % 1
        self.line_color = {
            math.sin(2 * math.pi * self.color_cycle) * 0.5 + 0.5,
            math.sin(2 * math.pi * (self.color_cycle + 1/3)) * 0.5 + 0.5,
            math.sin(2 * math.pi * (self.color_cycle + 2/3)) * 0.5 + 0.5,
            self.line_color[4]
        }
    elseif type(self.settings.line_color_animation) == "table" then
        local idx = (math.floor(self.color_cycle) % #self.settings.line_color_animation) + 1
        self.line_color = self.settings.line_color_animation[idx]
        self.color_cycle = self.color_cycle + 0.01
    end
end

function Particles:draw(draw_list, win_pos)
    for _, p in ipairs(self.particles) do
        local color = imgui.ColorConvertFloat4ToU32(imgui.ImVec4(p.color[1], p.color[2], p.color[3], p.color[4]))
        p:draw(draw_list, win_pos, color, self.settings.particle_size)
    end
    if self.settings.max_distance > 0 then
        local pd_sq = self.settings.max_distance * self.settings.max_distance
        for i = 1, #self.particles do
            local p1 = self.particles[i]
            for j = i + 1, #self.particles do
                local p2 = self.particles[j]
                local dx, dy = p1.x - p2.x, p1.y - p2.y
                local dist_sq = dx * dx + dy * dy
                if dist_sq < pd_sq then
                    local alpha = 1.0 - (math.sqrt(dist_sq) / self.settings.max_distance)
                    local lc = self.line_color
                    local line_col = imgui.ColorConvertFloat4ToU32(imgui.ImVec4(lc[1], lc[2], lc[3], lc[4] * alpha))
                    draw_list:AddLine(
                        imgui.ImVec2(win_pos.x + p1.x, win_pos.y + p1.y),
                        imgui.ImVec2(win_pos.x + p2.x, win_pos.y + p2.y),
                        line_col,
                        self.line_thickness
                    )
                end
            end
        end
    end
end

return Particles

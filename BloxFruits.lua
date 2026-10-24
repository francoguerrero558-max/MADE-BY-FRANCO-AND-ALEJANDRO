local BRAND = "by franco and Alejandro"

local CONFIG = {
    CHEST_FOLDER      = "ChestModels",
    ENEMY_FOLDER      = "Enemies",
    BOATS_FOLDER      = "Boats",
    SAFEZONE_ROOT     = "_WorldOrigin",

    OPEN_CHEST_REMOTE   = nil,
    ATTACK_REMOTE       = nil,
    SELL_REMOTE         = nil,
    STAT_REMOTE         = nil,
    PICKUP_FRUIT_REMOTE = nil,

    CHEST_COOLDOWN    = 0.35,
    MOB_COOLDOWN      = 0.25,
    FRUIT_COOLDOWN    = 0.3,
    ATTACK_RANGE      = 60,
    TP_HEIGHT_OFFSET  = 8,

    STAT_PRIORITY     = { "Melee", "Defense", "Sword", "Gun", "Blox Fruit" },

    TARGET_MOBS = {
        "Cake Queen","Captain Elephant","Demonic Soul","Grand Devotee",
        "High Disciple","Ice Cream Chef","Ice Cream Commander","Island Boy",
        "Isle Outlaw","Living Zombie","Longma","Ocean Prophet","Oni2",
        "Posessed Mummy","Reborn Skeleton","Stone","Deandre",
    },

    ISLANDS = {
        "TikiOutpost","HydraIslandClient","Great Tree","Haunted Castle",
        "Ice Cream Island","Peanut Island","Chocolate Island",
        "CakeLoaf","CandyCane","Turtle","Port",
    },

    BOATS = { "MarineSloop", "PirateGrandBrigade", "The Sentinel" },

    FRUIT_SPAWNERS = { "BananaSpawner", "AppleSpawner", "PineappleSpawner" },
}

local Players           = game:GetService("Players")
local TweenService      = game:GetService("TweenService")
local StarterGui        = game:GetService("StarterGui")
local RunService        = game:GetService("RunService")
local Workspace         = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer       = Players.LocalPlayer
local Mouse             = LocalPlayer:GetMouse()

local function Tween(obj, props, t)
    TweenService:Create(obj, TweenInfo.new(t or 0.2, Enum.EasingStyle.Quint), props):Play()
end

local function Protect(gui)
    if gethui then gui.Parent = gethui()
    elseif syn and syn.protect_gui then syn.protect_gui(gui); gui.Parent = game:GetService("CoreGui")
    else gui.Parent = game:GetService("CoreGui") end
end

local function New(class, props, parent)
    local inst = Instance.new(class)
    for k, v in pairs(props) do
        if k ~= "Children" and k ~= "Parent" then pcall(function() inst[k] = v end) end
    end
    if props.Children then for _, c in ipairs(props.Children) do pcall(function() c.Parent = inst end) end end
    inst.Parent = props.Parent or parent
    return inst
end

local function Ripple(btn, mx, my)
    task.spawn(function()
        btn.ClipsDescendants = true
        local nx, ny = mx - btn.AbsolutePosition.X, my - btn.AbsolutePosition.Y
        local sz = math.max(btn.AbsoluteSize.X, btn.AbsoluteSize.Y) * 1.6
        local c = New("ImageLabel", {
            Image = "rbxassetid://266543268", ImageColor3 = Color3.new(1,1,1),
            ImageTransparency = 0.82, BackgroundTransparency = 1,
            ZIndex = btn.ZIndex + 5, Size = UDim2.new(0, 0, 0, 0),
            Position = UDim2.new(0, nx, 0, ny),
        }, btn)
        Tween(c, { Size = UDim2.new(0, sz, 0, sz), Position = UDim2.new(0.5, -sz/2, 0.5, -sz/2) }, 0.45)
        Tween(c, { ImageTransparency = 1 }, 0.45)
        task.wait(0.46); c:Destroy()
    end)
end

local function Notify(title, desc, duration)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = title or BRAND, Text = desc or "", Duration = duration or 4,
        })
    end)
end

local function getRoot()
    local ch = LocalPlayer.Character
    return ch and ch:FindFirstChild("HumanoidRootPart")
end

local function nodePos(node)
    if not node then return nil end
    if node:IsA("Model") then
        if node.PrimaryPart then return node.PrimaryPart.Position end
        local bp = node:FindFirstChildWhichIsA("BasePart")
        return bp and bp.Position
    elseif node:IsA("BasePart") then return node.Position end
    return nil
end

local function tpTo(pos)
    local root = getRoot()
    if not root or not pos then return false end
    root.CFrame = CFrame.new(pos + Vector3.new(0, CONFIG.TP_HEIGHT_OFFSET, 0))
    return true
end

local function resolveRemote(name)
    if not name then return nil end
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    if not remotes then return nil end
    local r = remotes:FindFirstChild(name, true)
    return (r and r:IsA("RemoteEvent")) and r or nil
end

-- ─── SAFE ZONES ──────────────────────────────────────────────────────────
local function safeZonesFolder()
    local w = Workspace:FindFirstChild(CONFIG.SAFEZONE_ROOT)
    return w and w:FindFirstChild("SafeZones")
end
local function safeZonePart(zone)
    if zone:IsA("Model") then return zone.PrimaryPart or zone:FindFirstChildWhichIsA("BasePart")
    elseif zone:IsA("BasePart") then return zone end
    return nil
end
local function isInSafeZone(pos)
    pos = pos or (getRoot() and getRoot().Position)
    if not pos then return false end
    local folder = safeZonesFolder(); if not folder then return false end
    for _, zone in ipairs(folder:GetChildren()) do
        local part = safeZonePart(zone)
        if part then
            local rel = part.CFrame:PointToObjectSpace(pos)
            if math.abs(rel.X) <= part.Size.X/2 and math.abs(rel.Y) <= part.Size.Y/2 and math.abs(rel.Z) <= part.Size.Z/2 then
                return true, zone.Name
            end
        end
    end
    return false
end
local function nearestSafeZone(pos)
    pos = pos or (getRoot() and getRoot().Position); if not pos then return nil end
    local folder = safeZonesFolder(); if not folder then return nil end
    local best, bestDist, bestName = nil, math.huge, nil
    for _, zone in ipairs(folder:GetChildren()) do
        local part = safeZonePart(zone)
        if part then
            local d = (part.Position - pos).Magnitude
            if d < bestDist then best, bestDist, bestName = part, d, zone.Name end
        end
    end
    if best then return best, bestName end
end
local function tpToNearestSafe()
    local pos = getRoot() and getRoot().Position; if not pos then return false, "no character" end
    local part, name = nearestSafeZone(pos)
    if not part then return false, "no safe zone" end
    tpTo(part.Position); Notify(BRAND, "TP to " .. (name or "Safe Zone"), 3); return true
end

-- ─── CHEST FARM ──────────────────────────────────────────────────────────
local ChestFarm = { running = false, conn = nil }
local CHEST_TIERS = { Diamond = 1, Gold = 2, Silver = 3 }
local function chestTier(chest)
    for name, rank in pairs(CHEST_TIERS) do if chest.Name:lower():find(name:lower()) then return rank end end
    return 99
end
local function chestPart(chest)
    if chest:IsA("Model") then return chest.PrimaryPart or chest:FindFirstChildWhichIsA("BasePart")
    elseif chest:IsA("BasePart") then return chest end
    return nil
end
local function chestIsGone(chest)
    local part = chestPart(chest)
    if not part then return true end
    if chest.Parent and chest.Parent.Name ~= CONFIG.CHEST_FOLDER then return true end
    return false
end
function ChestFarm.tick()
    local folder = Workspace:FindFirstChild(CONFIG.CHEST_FOLDER); if not folder then return end
    local remote = resolveRemote(CONFIG.OPEN_CHEST_REMOTE)
    local root = getRoot(); local list = {}
    for _, chest in ipairs(folder:GetChildren()) do
        if not chestIsGone(chest) then
            local part = chestPart(chest)
            if part then
                local dist = root and (part.Position - root.Position).Magnitude or 999
                table.insert(list, { chest = chest, part = part, tier = chestTier(chest), dist = dist })
            end
        end
    end
    table.sort(list, function(a,b)
        if a.tier ~= b.tier then return a.tier < b.tier end
        return a.dist < b.dist
    end)
    for _, e in ipairs(list) do
        if not ChestFarm.running then break end
        if not chestIsGone(e.chest) then
            tpTo(e.part.Position); task.wait(0.1)
            if remote then pcall(function() remote:FireServer(e.chest) end) end
            task.wait(CONFIG.CHEST_COOLDOWN)
        end
    end
end
function ChestFarm.start()
    if ChestFarm.running then return end
    ChestFarm.running = true
    ChestFarm.conn = RunService.Heartbeat:Connect(function() if ChestFarm.running then ChestFarm.tick() end end)
end
function ChestFarm.stop()
    ChestFarm.running = false
    if ChestFarm.conn then ChestFarm.conn:Disconnect(); ChestFarm.conn = nil end
end

-- ─── MOB FARM ────────────────────────────────────────────────────────────
local MobFarm = { running = false, conn = nil }
local function isTargetMob(mob)
    for _, name in ipairs(CONFIG.TARGET_MOBS) do
        if mob.Name:lower():find(name:lower()) then return true end
    end
    return false
end
local function findNearestEnemy()
    local folder = Workspace:FindFirstChild(CONFIG.ENEMY_FOLDER)
    local root = getRoot(); if not folder or not root then return nil end
    local best, bestDist = nil, CONFIG.ATTACK_RANGE
    for _, mob in ipairs(folder:GetChildren()) do
        if isTargetMob(mob) then
            local pos = nodePos(mob)
            if pos and not isInSafeZone(pos) then
                local d = (pos - root.Position).Magnitude
                if d < bestDist then best, bestDist = mob, d end
            end
        end
    end
    return best
end
function MobFarm.start()
    if MobFarm.running then return end
    MobFarm.running = true
    MobFarm.conn = RunService.Heartbeat:Connect(function()
        if not MobFarm.running then return end
        local root = getRoot()
        if root and isInSafeZone(root.Position) then
            local t = findNearestEnemy(); local p = t and nodePos(t)
            if p then tpTo(p) end
            task.wait(0.5); return
        end
        local enemy = findNearestEnemy()
        if enemy then
            local pos = nodePos(enemy)
            if pos and root and (pos - root.Position).Magnitude > 10 then tpTo(pos) end
            local remote = resolveRemote(CONFIG.ATTACK_REMOTE)
            if remote then pcall(function() remote:FireServer(enemy) end) end
            task.wait(CONFIG.MOB_COOLDOWN)
        end
    end)
end
function MobFarm.stop()
    MobFarm.running = false
    if MobFarm.conn then MobFarm.conn:Disconnect(); MobFarm.conn = nil end
end

-- ─── FRUIT FARM ──────────────────────────────────────────────────────────
local FruitFarm = { running = false, conn = nil }
local function fruitSpawnsRoot()
    local w = Workspace:FindFirstChild(CONFIG.SAFEZONE_ROOT)
    return w and w:FindFirstChild("FruitSpawns")
end
local function fruitPart(obj)
    if obj:IsA("Model") then return obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
    elseif obj:IsA("BasePart") then return obj
    elseif obj:IsA("Tool") then
        local h = obj:FindFirstChild("Handle")
        if h and h:IsA("BasePart") then return h end
    end
    return nil
end
local function collectFruits()
    local out, seen = {}, {}
    local function add(p, o) if not p or seen[p] then return end; seen[p]=true; table.insert(out, {obj=o, part=p}) end
    local root = fruitSpawnsRoot()
    if root then
        for _, child in ipairs(root:GetChildren()) do
            if child:IsA("Model") or child:IsA("BasePart") or child:IsA("Tool") then
                local p = fruitPart(child); if p then add(p, child) end
                for _, sub in ipairs(child:GetChildren()) do
                    if sub:IsA("Model") or sub:IsA("BasePart") or sub:IsA("Tool") then
                        local sp = fruitPart(sub); if sp then add(sp, sub) end
                    end
                end
            end
        end
    end
    if #out == 0 then
        for _, name in ipairs(CONFIG.FRUIT_SPAWNERS) do
            local s = Workspace:FindFirstChild(name)
            if s then
                for _, child in ipairs(s:GetChildren()) do
                    if child:IsA("Model") or child:IsA("BasePart") or child:IsA("Tool") then
                        local p = fruitPart(child); if p then add(p, child) end
                    end
                end
            end
        end
    end
    return out
end
function FruitFarm.tick()
    local fruits = collectFruits(); if #fruits == 0 then return end
    local root = getRoot(); if not root then return end
    table.sort(fruits, function(a,b)
        return (a.part.Position - root.Position).Magnitude < (b.part.Position - root.Position).Magnitude
    end)
    for _, e in ipairs(fruits) do
        if not FruitFarm.running then break end
        tpTo(e.part.Position); task.wait(0.1)
        local remote = resolveRemote(CONFIG.PICKUP_FRUIT_REMOTE)
        if remote then pcall(function() remote:FireServer(e.obj) end) end
        task.wait(CONFIG.FRUIT_COOLDOWN)
    end
end
function FruitFarm.start()
    if FruitFarm.running then return end
    FruitFarm.running = true
    FruitFarm.conn = RunService.Heartbeat:Connect(function() if FruitFarm.running then FruitFarm.tick() end end)
end
function FruitFarm.stop()
    FruitFarm.running = false
    if FruitFarm.conn then FruitFarm.conn:Disconnect(); FruitFarm.conn = nil end
end

-- ─── AUTO STAT ───────────────────────────────────────────────────────────
local AutoStat = { running = false, conn = nil }
local function getStatPoints()
    local stats = LocalPlayer:FindFirstChild("leaderstats"); if not stats then return nil end
    for _, v in ipairs(stats:GetChildren()) do
        if v.Name:lower():find("point") or v.Name:lower():find("stat") then return v end
    end
    return nil
end
function AutoStat.start()
    if AutoStat.running then return end
    AutoStat.running = true
    AutoStat.conn = RunService.Heartbeat:Connect(function()
        if not AutoStat.running then return end
        local pts = getStatPoints()
        if pts and pts.Value > 0 then
            local remote = resolveRemote(CONFIG.STAT_REMOTE)
            if remote then pcall(function() remote:FireServer(CONFIG.STAT_PRIORITY[1] or "Melee") end) end
        end
        task.wait(1)
    end)
end
function AutoStat.stop()
    AutoStat.running = false
    if AutoStat.conn then AutoStat.conn:Disconnect(); AutoStat.conn = nil end
end

-- ─── AUTO SELL ───────────────────────────────────────────────────────────
local function AutoSell()
    local remote = resolveRemote(CONFIG.SELL_REMOTE)
    if remote then pcall(function() remote:FireServer() end); Notify(BRAND, "Sell sent.", 3)
    else Notify(BRAND, "No sell remote configured.", 3) end
end

-- ─── TELEPORTS ───────────────────────────────────────────────────────────
local function teleportTo(name)
    local node = Workspace:FindFirstChild(name)
    if not node then return false, name .. " not found" end
    local pos = nodePos(node)
    if not pos then return false, name .. " no position" end
    if not tpTo(pos) then return false, "no character" end
    Notify(BRAND, "TP to " .. name, 3); return true
end

-- ─── BOATS ───────────────────────────────────────────────────────────────
local function boatSpawnsFolder()
    local w = Workspace:FindFirstChild(CONFIG.SAFEZONE_ROOT)
    return w and w:FindFirstChild("BoatSpawns")
end
local function boardNearestBoat()
    local folder = Workspace:FindFirstChild(CONFIG.BOATS_FOLDER)
    if not folder then return false, "no boats" end
    local root = getRoot(); if not root then return false, "no character" end
    local best, bestDist = nil, math.huge
    for _, boat in ipairs(folder:GetChildren()) do
        local pos = nodePos(boat)
        if pos then
            local d = (pos - root.Position).Magnitude
            if d < bestDist then best, bestDist = boat, d end
        end
    end
    if not best then return false, "no boat" end
    local seat = best:FindFirstChildWhichIsA("VehicleSeat", true) or best:FindFirstChildWhichIsA("Seat", true)
    if not seat then return false, best.Name .. " no seat" end
    if seat.Occupant then return false, "boat occupied" end
    tpTo(seat.Position); task.wait(0.15)
    local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    if hum then pcall(function() seat:Sit(hum) end) end
    Notify(BRAND, "Boarding " .. best.Name, 3); return true
end
local function tpToNearestSpawn()
    local root = getRoot(); if not root then return false, "no character" end
    local folder = boatSpawnsFolder(); if not folder then return false, "no spawns" end
    local best, bestDist = nil, math.huge
    for _, part in ipairs(folder:GetChildren()) do
        if part:IsA("BasePart") then
            local d = (part.Position - root.Position).Magnitude
            if d < bestDist then best, bestDist = part, d end
        end
    end
    if not best then return false, "no spawn" end
    tpTo(best.Position); Notify(BRAND, "TP nearest spawn", 3); return true
end

-- ─── UI ──────────────────────────────────────────────────────────────────
local SG = Instance.new("ScreenGui")
SG.Name = "FrancoAlejandro_" .. tostring(math.random(1e6))
SG.ResetOnSpawn = false
SG.IgnoreGuiInset = true
Protect(SG)

local PANEL_W, PANEL_H = 340, 420
local PILL_W, PILL_H = 60, 32

local Panel = New("Frame", {
    Name = "Main",
    BackgroundColor3 = Color3.fromRGB(15, 12, 24),
    BorderSizePixel = 0,
    Size = UDim2.new(0, PANEL_W, 0, PANEL_H),
    Position = UDim2.new(0, 20, 0, 80),
    ZIndex = 250, Parent = SG,
    Children = {
        New("UICorner", { CornerRadius = UDim.new(0, 12) }),
        New("UIStroke", { Color = Color3.fromRGB(120, 60, 220), Transparency = 0.3, Thickness = 1.2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
    },
})

New("Frame", { BackgroundColor3 = Color3.fromRGB(80, 20, 160), BackgroundTransparency = 0.88,
    BorderSizePixel = 0, Position = UDim2.new(0, -40, 0, -40), Size = UDim2.new(0, 140, 0, 140),
    ZIndex = 251, Parent = Panel, Children = { New("UICorner", { CornerRadius = UDim.new(1, 0) }) } })
New("Frame", { BackgroundColor3 = Color3.fromRGB(40, 10, 110), BackgroundTransparency = 0.88,
    BorderSizePixel = 0, Position = UDim2.new(1, -70, 1, -70), Size = UDim2.new(0, 120, 0, 120),
    ZIndex = 251, Parent = Panel, Children = { New("UICorner", { CornerRadius = UDim.new(1, 0) }) } })

local Header = New("Frame", {
    BackgroundColor3 = Color3.fromRGB(22, 16, 36), BorderSizePixel = 0,
    Size = UDim2.new(1, 0, 0, 34), ZIndex = 252, Parent = Panel,
    Children = {
        New("UICorner", { CornerRadius = UDim.new(0, 12) }),
        New("Frame", { BackgroundColor3 = Color3.fromRGB(22, 16, 36), BorderSizePixel = 0,
            Position = UDim2.new(0, 0, 0.5, 0), Size = UDim2.new(1, 0, 0.5, 0), ZIndex = 252 }),
    },
})
New("ImageLabel", { BackgroundTransparency = 1, Position = UDim2.new(0, 10, 0.5, -7),
    Size = UDim2.new(0, 14, 0, 14), Image = "rbxassetid://7733992528",
    ImageColor3 = Color3.fromRGB(155, 90, 255), ZIndex = 253, Parent = Header })
New("TextLabel", { BackgroundTransparency = 1, Position = UDim2.new(0, 28, 0, 0),
    Size = UDim2.new(1, -100, 1, 0), Font = Enum.Font.FredokaOne,
    Text = BRAND, TextColor3 = Color3.fromRGB(220, 200, 255),
    TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 253, Parent = Header })

local MinBtn = New("TextButton", {
    BackgroundColor3 = Color3.fromRGB(60, 30, 110), BorderSizePixel = 0,
    AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -64, 0.5, 0),
    Size = UDim2.new(0, 20, 0, 20), AutoButtonColor = false, Text = "–",
    Font = Enum.Font.GothamBold, TextColor3 = Color3.fromRGB(220, 200, 255), TextSize = 14,
    ZIndex = 253, Parent = Header,
    Children = { New("UICorner", { CornerRadius = UDim.new(0, 5) }) },
})
local CloseBtn = New("TextButton", {
    BackgroundColor3 = Color3.fromRGB(60, 25, 30), BorderSizePixel = 0,
    AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0),
    Size = UDim2.new(0, 20, 0, 20), AutoButtonColor = false, Text = "×",
    Font = Enum.Font.GothamBold, TextColor3 = Color3.fromRGB(240, 160, 160), TextSize = 16,
    ZIndex = 253, Parent = Header,
    Children = { New("UICorner", { CornerRadius = UDim.new(0, 5) }) },
})
CloseBtn.MouseButton1Click:Connect(function() SG:Destroy() end)

New("Frame", { BackgroundColor3 = Color3.fromRGB(120, 60, 220), BackgroundTransparency = 0.3,
    BorderSizePixel = 0, Position = UDim2.new(0, 0, 0, 34), Size = UDim2.new(1, 0, 0, 1),
    ZIndex = 252, Parent = Panel })

local Content = New("ScrollingFrame", {
    BackgroundTransparency = 1, BorderSizePixel = 0,
    Position = UDim2.new(0, 8, 0, 42),
    Size = UDim2.new(1, -16, 1, -50),
    ScrollBarThickness = 3,
    ScrollBarImageColor3 = Color3.fromRGB(120, 60, 220),
    CanvasSize = UDim2.new(0, 0, 0, 0),
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
    ZIndex = 252, Parent = Panel,
})
New("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = Content })

local Pill = New("TextButton", {
    Name = "Pill",
    BackgroundColor3 = Color3.fromRGB(22, 16, 36), BorderSizePixel = 0,
    Position = UDim2.new(0, 20, 0, 80),
    Size = UDim2.new(0, PILL_W, 0, PILL_H),
    AutoButtonColor = false, Text = "",
    Visible = false, ZIndex = 260, Parent = SG,
    Children = {
        New("UICorner", { CornerRadius = UDim.new(0, 16) }),
        New("UIStroke", { Color = Color3.fromRGB(120, 60, 220), Transparency = 0.3, Thickness = 1.2 }),
        New("ImageLabel", { BackgroundTransparency = 1, Position = UDim2.new(0, 6, 0.5, -7),
            Size = UDim2.new(0, 14, 0, 14), Image = "rbxassetid://7733992528",
            ImageColor3 = Color3.fromRGB(155, 90, 255), ZIndex = 261 }),
        New("TextLabel", { BackgroundTransparency = 1, Position = UDim2.new(0, 24, 0, 0),
            Size = UDim2.new(1, -28, 1, 0), Font = Enum.Font.FredokaOne,
            Text = "QO", TextColor3 = Color3.fromRGB(220, 200, 255),
            TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 261 }),
    },
})

local minimized = false
local function setMinimized(state)
    minimized = state
    if state then
        Pill.Position = Panel.Position
        Panel.Visible = false
        Pill.Visible = true
    else
        Panel.Position = Pill.Position
        Panel.Visible = true
        Pill.Visible = false
    end
end
MinBtn.MouseButton1Click:Connect(function() setMinimized(true) end)
Pill.MouseButton1Click:Connect(function() setMinimized(false) end)

local function SectionLabel(text)
    New("TextLabel", {
        BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 14),
        Font = Enum.Font.GothamBold, Text = text,
        TextColor3 = Color3.fromRGB(160, 110, 240), TextSize = 9,
        TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 253, Parent = Content,
    })
end

local function MakeBtn(label, bg, tc, cb)
    local btn = New("TextButton", {
        BackgroundColor3 = bg, BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 26), AutoButtonColor = false, Text = "",
        ClipsDescendants = true, ZIndex = 252, Parent = Content,
        Children = {
            New("UICorner", { CornerRadius = UDim.new(0, 6) }),
            New("TextLabel", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0),
                Font = Enum.Font.FredokaOne, Text = label, TextColor3 = tc, TextSize = 11,
                TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 253 }),
        },
    })
    btn.MouseEnter:Connect(function() Tween(btn, { BackgroundColor3 = bg:Lerp(Color3.new(1,1,1), 0.15) }, 0.12) end)
    btn.MouseLeave:Connect(function() Tween(btn, { BackgroundColor3 = bg }, 0.16) end)
    btn.MouseButton1Click:Connect(function() Ripple(btn, Mouse.X, Mouse.Y); cb(btn) end)
    return btn
end
local function setLbl(btn, text)
    local l = btn:FindFirstChildOfClass("TextLabel")
    if l then l.Text = text end
end

SectionLabel("FARM")

local chestBtn = MakeBtn("Chest Farm: OFF", Color3.fromRGB(45, 20, 85), Color3.fromRGB(200, 165, 255), function(btn)
    if ChestFarm.running then ChestFarm.stop(); setLbl(btn, "Chest Farm: OFF")
    else ChestFarm.start(); setLbl(btn, "Chest Farm: ON") end
end)
local mobBtn = MakeBtn("Mob Farm: OFF", Color3.fromRGB(45, 20, 85), Color3.fromRGB(200, 165, 255), function(btn)
    if MobFarm.running then MobFarm.stop(); setLbl(btn, "Mob Farm: OFF")
    else MobFarm.start(); setLbl(btn, "Mob Farm: ON") end
end)
local fruitBtn = MakeBtn("Fruit Farm: OFF", Color3.fromRGB(45, 20, 85), Color3.fromRGB(200, 165, 255), function(btn)
    if FruitFarm.running then FruitFarm.stop(); setLbl(btn, "Fruit Farm: OFF")
    else FruitFarm.start(); setLbl(btn, "Fruit Farm: ON") end
end)
local statBtn = MakeBtn("Auto Stat: OFF", Color3.fromRGB(45, 20, 85), Color3.fromRGB(200, 165, 255), function(btn)
    if AutoStat.running then AutoStat.stop(); setLbl(btn, "Auto Stat: OFF")
    else AutoStat.start(); setLbl(btn, "Auto Stat: ON") end
end)
MakeBtn("Auto Sell Now", Color3.fromRGB(65, 25, 130), Color3.fromRGB(225, 180, 255), AutoSell)

SectionLabel("ISLANDS")
for _, islandName in ipairs(CONFIG.ISLANDS) do
    MakeBtn("TP · " .. islandName, Color3.fromRGB(20, 45, 90), Color3.fromRGB(130, 195, 255), function()
        local ok, err = teleportTo(islandName)
        if not ok then Notify(BRAND, tostring(err or "failed"), 3) end
    end)
end

SectionLabel("BOATS")
MakeBtn("Board Nearest Boat", Color3.fromRGB(65, 25, 130), Color3.fromRGB(225, 180, 255), function()
    local ok, err = boardNearestBoat()
    if not ok then Notify(BRAND, tostring(err or "failed"), 3) end
end)
MakeBtn("TP · Nearest Spawn", Color3.fromRGB(20, 45, 90), Color3.fromRGB(130, 195, 255), function()
    local ok, err = tpToNearestSpawn()
    if not ok then Notify(BRAND, tostring(err or "failed"), 3) end
end)

SectionLabel("SAFETY")
MakeBtn("TP · Nearest Safe Zone", Color3.fromRGB(20, 45, 90), Color3.fromRGB(130, 195, 255), function()
    local ok, err = tpToNearestSafe()
    if not ok then Notify(BRAND, tostring(err or "failed"), 3) end
end)
MakeBtn("Am I Safe?", Color3.fromRGB(45, 20, 85), Color3.fromRGB(200, 165, 255), function()
    local inside, name = isInSafeZone()
    Notify(BRAND, inside and ("Safe: " .. tostring(name)) or "Not in a safe zone.", 3)
end)

local dragging, dragStart, startPos
local function bindDrag(handle, target)
    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true; dragStart = input.Position; startPos = target.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    target.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            if dragging then
                local d = input.Position - dragStart
                target.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
            end
        end
    end)
end
bindDrag(Header, Panel)
bindDrag(Pill, Pill)

Notify(BRAND, "Loaded — compact panel ready.", 3)

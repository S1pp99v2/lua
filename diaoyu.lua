--[[
	钓鱼大师 助手（自动钓鱼 / 自动技能 / 自动 QTE）

	设计原则：不伪造网络包，一律走游戏自己的输入回调。
	FishingPrimary.Pressed / Released 就是玩家按键时走的那两个处理函数，
	用 getconnections 触发它们，游戏自身的门检（本地抛竿门、CPS 节流、
	状态接收表 AcceptsPacket）全部照常生效。
	直接发 FishCast 包是行不通的：客户端按状态过滤服务端回包，
	状态不推进到 Waiting 就会把 FishWaitingAck 丢掉，整个状态机就乱了。

	所有节奏都按人类可达范围取值并带抖动，理由见各处注释里的反作弊参数。
]]

local RS = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")
local TWS = game:GetService("TweenService")
local LP = game:GetService("Players").LocalPlayer
local PG = LP:WaitForChild("PlayerGui")

local GEN = (getgenv().__DiaoyuGen or 0) + 1
getgenv().__DiaoyuGen = GEN
local function alive()
	return getgenv().__DiaoyuGen == GEN
end

local conns = {}
local function track(c)
	if c then
		conns[#conns + 1] = c
	end
	return c
end

-- 控制器都注册在 shared 上（MS-Client 的 CreateController 里 shared[Name] = controller），
-- 所以不用 require 就能取到。不过 RodController 里是直接 require 兄弟模块的，
-- 万一某个控制器没走注册流程，就退回 require ReplicatedStorage.Controllers.<Name>。
local function ctl(name)
	local c = shared[name]
	if type(c) == "table" then
		return c
	end
	local folder = RS:FindFirstChild("Controllers")
	local mod = folder and folder:FindFirstChild(name)
	if mod then
		local ok, m = pcall(require, mod)
		if ok and type(m) == "table" then
			return m
		end
	end
	return nil
end

-- 等控制器就位（脚本可能在游戏还没起完时执行）
local fishing, rod, pdata
for _ = 1, 60 do
	fishing = ctl("FishingController")
	rod = ctl("RodController")
	pdata = ctl("PlayerDataV2Controller")
	if fishing and rod then
		break
	end
	task.wait(0.5)
end

if not (fishing and rod) then
	warn("[Diaoyu] 找不到 FishingController / RodController，先别开开关，游戏起完再重跑")
	return
end

-- ===== 输入层 =====
-- 找出游戏 authored 的 InputAction 实例，拿它的连接当"虚拟按键"。
local function findAction(name)
	for _, d in ipairs(RS:GetDescendants()) do
		if d.Name == name and d:IsA("InputAction") then
			return d
		end
	end
end

local ACTION_CACHE = {}

local function actionOf(name)
	if ACTION_CACHE[name] ~= nil then
		return ACTION_CACHE[name] or nil
	end
	local a = findAction(name)
	ACTION_CACHE[name] = a or false
	return a
end

local function fireAction(name, evt)
	local a = actionOf(name)
	if not a then
		return false
	end
	local ok = pcall(function()
		for _, c in ipairs(getconnections(a[evt])) do
			c:Fire()
		end
	end)
	return ok
end

local function pressPrimary()
	return fireAction("FishingPrimary", "Pressed")
end

local function releasePrimary()
	return fireAction("FishingPrimary", "Released")
end

local hasConn = type(getconnections) == "function"
local primaryOk = hasConn and actionOf("FishingPrimary") ~= nil

-- ===== 数值（全部取自 dump 里的配置）=====
-- 拉条是三角波：pos = (serverNow-startTime)*2.4 % 2，>1 时取 2-pos，周期约 0.833s
-- 判定区 PullBar.Zones：<=0.4154 x1 / <=0.6923 x3 / <=0.8769 x5 / <=1.0 x10
local PULL_PERFECT_AT = 0.8769
-- 抛竿力度：LuckBar.Threshold = 0.8 起算 Perfect，力度还决定落点 30~60 studs
local CAST_MIN, CAST_MAX = 30, 60
-- 本地收线点击上限 ManualCps = 6，容差 ManualJitterTolerance = 0.05
local REEL_CPS_CAP = 6
-- QTE 反作弊参数：Latency.QteReactionFloor = 0.1，QteFastPenaltyCount = 5
-- 反应太快会被记惩罚，所以最小延迟必须高于 0.1 且带抖动
local QTE_FLOOR = 0.1

local CFG = {
	Fishing = false,
	Casting = true,
	FirstPull = true,
	Reel = true,
	Skills = false,
	QTE = true,
	CastPower = 0.85,
	PullAt = 0.90,
	ReelCps = 5.5,
	QteMin = 0.15,
	QteMax = 0.36,
	SkillGap = 1.2,
	MinHpToSkill = 0,
}

local last = {}
local function gate(key, secs)
	local t = os.clock()
	if not last[key] or t - last[key] > secs then
		last[key] = t
		return true
	end
	return false
end

local function state()
	local ok, s = pcall(function()
		return fishing:GetState()
	end)
	return ok and s or nil
end

local function pullBar()
	local ok, v = pcall(function()
		return fishing:GetPullBarValue()
	end)
	return ok and tonumber(v) or nil
end

local function luckBar()
	local ok, v = pcall(function()
		return fishing:GetLuckBarValue()
	end)
	return ok and tonumber(v) or nil
end

local function isReeling()
	local ok, v = pcall(function()
		return fishing:IsReeling()
	end)
	return ok and v == true
end

local function isAutoSession()
	local ok, v = pcall(function()
		return fishing:IsAutoSession()
	end)
	return ok and v == true
end

-- 抛竿落点：照搬 CalcTargetPos 的算法，Y 用水位
local Catalog
pcall(function()
	Catalog = require(RS.Data.Catalog)
end)

local function targetPos(power)
	local char = LP.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not (hrp and hrp:IsA("BasePart")) then
		return nil
	end
	local dist = CAST_MIN + power * (CAST_MAX - CAST_MIN)
	local look = hrp.CFrame.LookVector
	local unit = Vector3.new(look.X, 0, look.Z)
	if unit.Magnitude < 0.001 then
		return nil
	end
	unit = unit.Unit
	local waterY = hrp.Position.Y
	if Catalog and Catalog.Island and Catalog.Island.GetWaterY then
		local ok, y = pcall(function()
			local isl = ctl("IslandRegionController")
			local id = isl and isl:GetCurrentIslandId() or ""
			return Catalog.Island.GetWaterY(id)
		end)
		if ok and tonumber(y) then
			waterY = tonumber(y)
		end
	end
	return Vector3.new(
		hrp.Position.X + unit.X * dist,
		waterY,
		hrp.Position.Z + unit.Z * dist
	)
end

-- ===== 状态 =====
local castPhase = nil -- nil / "holding" / "throwing"
local castAt = 0
local reelSeq = math.random(1, 60000)
local pendingQte = nil
local qteAt = 0
local stats = { cast = 0, pull = 0, click = 0, skill = 0, qte = 0 }
local statusLbl, statLbl, pathLbl
local skillCd = {}

-- ===== 抛竿 =====
-- Idling 时按下 -> Holding -> 0.15s 后自动进 Throwing（蓄力条开始摆动）
-- -> 到力度目标时松开，游戏自己算落点并发 FishCast
local function tryCast()
	if state() ~= "Idling" then
		return false
	end
	if isAutoSession() then
		return false
	end
	if not primaryOk then
		return false
	end
	if not pressPrimary() then
		return false
	end
	castPhase = "holding"
	castAt = os.clock()
	stats.cast = stats.cast + 1
	return true
end

-- 蓄力期间每一帧看力度条，够了就松手
local function tickCast()
	if not castPhase then
		return
	end
	local st = state()
	if st ~= "Holding" and st ~= "Throwing" then
		castPhase = nil
		return
	end
	if castPhase == "holding" then
		-- 最短握杆 0.15s，给一点人类冗余
		if os.clock() - castAt < 0.16 + math.random() * 0.06 then
			return
		end
		castPhase = "throwing"
		return
	end
	local v = luckBar()
	if v == nil then
		return
	end
	-- 留一点提前量：松手到服务端收到有往返
	local lead = math.clamp(LP:GetNetworkPing() * 0.5 * 1.8, 0, 0.06)
	if v >= (CFG.CastPower - lead) then
		castPhase = nil
		releasePrimary()
	end
end

-- ===== 首拉 =====
-- 拉条进 x10 区（>=0.8769）就报钩。加一点随机延迟是为了不做帧级精确，
-- 0.03s 在 2.4/s 的摆速下只挪 0.072，仍在区内
local function tickFirstPull()
	if state() ~= "FirstPull" then
		return
	end
	if not primaryOk then
		-- 退路：直接发首拉包（首拉不需要本地状态推进，服务端认）
		local v = pullBar()
		if v and v >= CFG.PullAt and gate("pull", 0.4) then
			pcall(function()
				fishing.FishFirstPull:Fire()
			end)
			stats.pull = stats.pull + 1
		end
		return
	end
	local v = pullBar()
	if not v then
		return
	end
	if v >= CFG.PullAt and gate("pull", 0.4) then
		task.delay(math.random() * 0.03, function()
			if alive() and state() == "FirstPull" then
				pressPrimary()
				stats.pull = stats.pull + 1
			end
		end)
	end
end

-- ===== 收线点击 =====
-- 本地节流上限 6 CPS，取 5.5 并加抖动，既不超人类上限也不做等间隔机器节奏
local function tickReel()
	if not isReeling() then
		return
	end
	if CFG.ReelCps <= 0 then
		return
	end
	local interval = 1 / math.min(CFG.ReelCps, REEL_CPS_CAP)
	if not gate("reel", interval * (0.88 + math.random() * 0.24)) then
		return
	end
	if primaryOk then
		if pressPrimary() then
			stats.click = stats.click + 1
		end
		return
	end
	-- 退路：直接发收线包，seq 是循环序号（上限 65535）
	reelSeq = reelSeq % 65535 + 1
	pcall(function()
		fishing.FishReelPull:Fire(reelSeq)
	end)
	stats.click = stats.click + 1
end

-- ===== 技能 =====
-- 唯一入口 Moveset:Fire(slotName, skillId)，skillId 在 PlayerData.Rods[rodId].BookSlots[slot]
-- 冷却以服务端推的 ReplicatedSkillCooldown 为准
track(rod.ReplicatedSkillCooldown.OnClientEvent:Connect(function(tbl)
	if typeof(tbl) ~= "table" then
		return
	end
	for slot, v in pairs(tbl) do
		if type(slot) == "string" and typeof(v) == "table" then
			skillCd[slot] = v.phase
		end
	end
end))

local function trySkills()
	if not isReeling() or isAutoSession() then
		return
	end
	if LP:GetAttribute("IsUsingSkill") then
		return
	end
	if not gate("skill", math.max(0.6, CFG.SkillGap or 1.2)) then
		return
	end
	local data
	pcall(function()
		data = pdata and pdata:Fetch()
	end)
	if type(data) ~= "table" then
		return
	end
	local rodId = data.RodEquip
	local entry = rodId and data.Rods and data.Rods[rodId]
	local books = entry and entry.BookSlots
	if type(books) ~= "table" then
		return
	end
	for i = 1, 4 do
		local slot = "Slot" .. i
		local phase = skillCd[slot]
		if phase == nil or phase == "Ready" then
			local skillId = books[slot]
			if type(skillId) == "string" and skillId ~= "" then
				skillCd[slot] = "Casting"
				pcall(function()
					rod.Moveset:Fire(slot, skillId)
				end)
				stats.skill = stats.skill + 1
				return -- 一次只放一个，冷却与施法状态由服务端回推
			end
		end
	end
end

-- ===== QTE（A / W / D）=====
-- 服务端 FishQTEPrompt(direction, duration) 下发方向，
-- 映射 Left=A / Right=D / Up=W；应答走游戏自己的 QTE 动作回调
local QTE_KEY = { Left = "QTE_A", Right = "QTE_D", Up = "QTE_W" }

track(fishing.FishQTEPrompt.OnClientEvent:Connect(function(direction, duration)
	if not alive() or not CFG.QTE then
		return
	end
	local act = QTE_KEY[direction]
	if not act then
		return
	end
	-- 反作弊：QteReactionFloor = 0.1，连续过快达 5 次会被记；
	-- 所以延迟下限锁在 0.15 且随机，绝不做 0 延迟
	local lo = math.max(QTE_FLOOR + 0.05, CFG.QteMin or 0.15)
	local hi = math.max(lo + 0.02, CFG.QteMax or 0.36)
	local wait = lo + math.random() * (hi - lo)
	local win = tonumber(duration)
	if win and win > 0.3 then
		-- 别把反应时间拖到窗口外
		wait = math.min(wait, win * 0.6)
	end
	pendingQte = act
	qteAt = os.clock() + wait
end))

local function tickQte()
	if not pendingQte or os.clock() < qteAt then
		return
	end
	local act = pendingQte
	pendingQte = nil
	if fireAction(act, "Pressed") then
		stats.qte = stats.qte + 1
	end
end

-- ===== 主循环 =====
task.spawn(function()
	while alive() do
		if CFG.Fishing then
			local st = state()
			if st == "Idling" then
				if gate("cast", 0.8) then
					tryCast()
				end
			elseif st == "Holding" or st == "Throwing" then
				if CFG.Casting then
					tickCast()
				end
			elseif st == "FirstPull" then
				if CFG.FirstPull then
					tickFirstPull()
				end
			elseif st == "Reeling" then
				if CFG.Reel then
					tickReel()
				end
				if CFG.Skills then
					trySkills()
				end
			end
			tickQte()
		else
			castPhase = nil
			pendingQte = nil
		end
		if statusLbl then
			local st = state() or "?"
			statusLbl.Text = ("状态 %s · 抛竿%d 首拉%d 点击%d 技能%d QTE%d"):format(
				st, stats.cast, stats.pull, stats.click, stats.skill, stats.qte
			)
		end
		task.wait(0.02)
	end
end)

-- ===== 界面 =====
local old = PG:FindFirstChild("DiaoyuHub")
if old then
	old:Destroy()
end

local gui = Instance.new("ScreenGui")
gui.Name = "DiaoyuHub"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder = 999999
gui.Parent = PG

local function shutdown()
	pcall(function()
		local g = getgenv()
		-- 只能往上加，置 nil 会让下一个实例拿到同一个 GEN，把已死的旧实例复活
		g.__DiaoyuGen = (tonumber(g.__DiaoyuGen) or 0) + 1
	end)
	for _, c in ipairs(conns) do
		pcall(function()
			c:Disconnect()
		end)
	end
	table.clear(conns)
	pcall(function()
		gui:Destroy()
	end)
end

local cam = workspace.CurrentCamera
local touch = UIS.TouchEnabled and not UIS.MouseEnabled
local WIDE = 268
local BAR = 40
local ROWH = touch and 34 or 30

local panel = Instance.new("Frame")
panel.Size = UDim2.new(0, WIDE, 0, 360)
panel.Position = UDim2.new(0, touch and 12 or 24, 0.5, -180)
panel.BackgroundColor3 = Color3.fromRGB(14, 16, 22)
panel.BorderSizePixel = 0
panel.ClipsDescendants = true
panel.Active = true
panel.Parent = gui
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 8)
local ps = Instance.new("UIStroke", panel)
ps.Color = Color3.fromRGB(60, 68, 90)
ps.Transparency = 0.35

local bar = Instance.new("Frame", panel)
bar.Size = UDim2.new(1, 0, 0, BAR)
bar.BackgroundColor3 = Color3.fromRGB(21, 24, 33)
bar.BorderSizePixel = 0
Instance.new("UICorner", bar).CornerRadius = UDim.new(0, 8)
local barFix = Instance.new("Frame", bar)
barFix.Size = UDim2.new(1, 0, 0, 8)
barFix.Position = UDim2.new(0, 0, 1, -8)
barFix.BackgroundColor3 = Color3.fromRGB(21, 24, 33)
barFix.BorderSizePixel = 0

local title = Instance.new("TextLabel", bar)
title.Size = UDim2.new(1, -92, 1, 0)
title.Position = UDim2.new(0, 18, 0, 0)
title.BackgroundTransparency = 1
title.Text = "钓鱼大师 AUTO"
title.Font = Enum.Font.GothamBold
title.TextSize = 14
title.TextColor3 = Color3.fromRGB(228, 234, 247)
title.TextXAlignment = Enum.TextXAlignment.Left

local function iconBtn(x, txt)
	local b = Instance.new("TextButton", bar)
	b.Size = UDim2.new(0, 24, 0, 24)
	b.AnchorPoint = Vector2.new(0.5, 0.5)
	b.Position = UDim2.new(1, x, 0.5, 0)
	b.BackgroundColor3 = Color3.fromRGB(38, 43, 58)
	b.BorderSizePixel = 0
	b.Text = txt
	b.Font = Enum.Font.GothamBold
	b.TextSize = 14
	b.TextColor3 = Color3.fromRGB(198, 206, 224)
	b.AutoButtonColor = false
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 5)
	return b
end

local mini = iconBtn(-22, "—")

local body = Instance.new("ScrollingFrame", panel)
body.Size = UDim2.new(1, 0, 1, -BAR)
body.Position = UDim2.new(0, 0, 0, BAR)
body.BackgroundTransparency = 1
body.BorderSizePixel = 0
body.ScrollBarThickness = touch and 5 or 8
body.ScrollBarImageColor3 = Color3.fromRGB(90, 100, 125)
body.ScrollBarImageTransparency = 0.4
body.ScrollingDirection = Enum.ScrollingDirection.Y
body.AutomaticCanvasSize = Enum.AutomaticSize.Y
body.CanvasSize = UDim2.new(0, 0, 0, 0)
local list = Instance.new("UIListLayout", body)
list.SortOrder = Enum.SortOrder.LayoutOrder
list.Padding = UDim.new(0, touch and 4 or 6)
local pad = Instance.new("UIPadding", body)
pad.PaddingTop = UDim.new(0, 10)
pad.PaddingBottom = UDim.new(0, 12)
pad.PaddingLeft = UDim.new(0, 12)
pad.PaddingRight = UDim.new(0, 12)

local order = 0
local function nxt()
	order = order + 1
	return order
end

local function row(label, key, isToggle)
	local r = Instance.new("TextButton", body)
	r.Size = UDim2.new(1, 0, 0, ROWH)
	r.LayoutOrder = nxt()
	r.BackgroundTransparency = 1
	r.Text = ""
	r.AutoButtonColor = false

	local nm = Instance.new("TextLabel", r)
	nm.Size = UDim2.new(1, -58, 1, 0)
	nm.Position = UDim2.new(0, 2, 0, 0)
	nm.BackgroundTransparency = 1
	nm.Text = label
	nm.Font = Enum.Font.Gotham
	nm.TextSize = 13
	nm.TextColor3 = Color3.fromRGB(196, 204, 220)
	nm.TextXAlignment = Enum.TextXAlignment.Left

	if isToggle then
		local track2 = Instance.new("Frame", r)
		track2.Size = UDim2.new(0, 40, 0, 20)
		track2.AnchorPoint = Vector2.new(1, 0.5)
		track2.Position = UDim2.new(1, 0, 0.5, 0)
		track2.BackgroundColor3 = Color3.fromRGB(50, 55, 72)
		track2.BorderSizePixel = 0
		Instance.new("UICorner", track2).CornerRadius = UDim.new(0, 4)

		local knob = Instance.new("Frame", track2)
		knob.Size = UDim2.new(0, 14, 0, 14)
		knob.Position = UDim2.new(0, 3, 0.5, -7)
		knob.BackgroundColor3 = Color3.fromRGB(148, 156, 175)
		knob.BorderSizePixel = 0
		Instance.new("UICorner", knob).CornerRadius = UDim.new(0, 4)

		local function paint(anim)
			local on = CFG[key]
			local ti = TweenInfo.new(anim and 0.22 or 0, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
			TWS:Create(knob, ti, {
				Position = on and UDim2.new(0, 23, 0.5, -7) or UDim2.new(0, 3, 0.5, -7),
				BackgroundColor3 = on and Color3.fromRGB(96, 232, 180) or Color3.fromRGB(148, 156, 175),
			}):Play()
			TWS:Create(track2, ti, {
				BackgroundColor3 = on and Color3.fromRGB(28, 68, 58) or Color3.fromRGB(50, 55, 72),
			}):Play()
			TWS:Create(nm, ti, {
				TextColor3 = on and Color3.fromRGB(242, 248, 255) or Color3.fromRGB(150, 158, 176),
			}):Play()
		end
		paint(false)
		r.MouseButton1Click:Connect(function()
			CFG[key] = not CFG[key]
			paint(true)
		end)
		return r
	end

	local btn = Instance.new("TextLabel", r)
	btn.Size = UDim2.new(0, 74, 0, 22)
	btn.AnchorPoint = Vector2.new(0.5, 0.5)
	btn.Position = UDim2.new(1, -37, 0.5, 0)
	btn.BackgroundColor3 = Color3.fromRGB(40, 45, 60)
	btn.BorderSizePixel = 0
	btn.Text = ""
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 11
	btn.TextColor3 = Color3.fromRGB(226, 232, 245)
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)
	r.MouseButton1Click:Connect(function()
		if key == "__exit" then
			shutdown()
		end
	end)
	return btn
end

local function info(color)
	local l = Instance.new("TextLabel", body)
	l.Size = UDim2.new(1, 0, 0, 18)
	l.LayoutOrder = nxt()
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.GothamBold
	l.TextSize = 11
	l.TextColor3 = color or Color3.fromRGB(140, 150, 175)
	l.TextXAlignment = Enum.TextXAlignment.Left
	return l
end

local function inputRow(label, key, minv, maxv)
	local r = Instance.new("Frame", body)
	r.Size = UDim2.new(1, 0, 0, ROWH)
	r.LayoutOrder = nxt()
	r.BackgroundTransparency = 1

	local nm = Instance.new("TextLabel", r)
	nm.Size = UDim2.new(1, -72, 1, 0)
	nm.Position = UDim2.new(0, 2, 0, 0)
	nm.BackgroundTransparency = 1
	nm.Text = label
	nm.Font = Enum.Font.Gotham
	nm.TextSize = 13
	nm.TextColor3 = Color3.fromRGB(180, 188, 206)
	nm.TextXAlignment = Enum.TextXAlignment.Left

	local box = Instance.new("TextBox", r)
	box.Size = UDim2.new(0, 58, 0, 22)
	box.AnchorPoint = Vector2.new(0.5, 0.5)
	box.Position = UDim2.new(1, -29, 0.5, 0)
	box.BackgroundColor3 = Color3.fromRGB(40, 45, 60)
	box.BorderSizePixel = 0
	box.Text = tostring(CFG[key])
	box.ClearTextOnFocus = false
	box.Font = Enum.Font.GothamBold
	box.TextSize = 11
	box.TextColor3 = Color3.fromRGB(226, 232, 245)
	Instance.new("UICorner", box).CornerRadius = UDim.new(0, 4)
	box.FocusLost:Connect(function()
		local n = tonumber(box.Text)
		if n then
			CFG[key] = math.clamp(n, minv, maxv)
		end
		box.Text = tostring(CFG[key])
	end)
end

row("自动钓鱼", "Fishing", true)
row("自动抛竿蓄力", "Casting", true)
row("自动首拉(完美区)", "FirstPull", true)
row("自动收线点击", "Reel", true)
row("自动释放技能", "Skills", true)
row("自动 QTE(A/W/D)", "QTE", true)

local sec1 = info(Color3.fromRGB(110, 118, 138))
sec1.Text = "— 参数 —"
inputRow("抛竿力度", "CastPower", 0, 1)
inputRow("首拉触发点", "PullAt", 0.8769, 1)
inputRow("收线 CPS", "ReelCps", 1, 6)
inputRow("QTE 延迟下限", "QteMin", 0.15, 2)
inputRow("QTE 延迟上限", "QteMax", 0.17, 3)
inputRow("技能间隔秒", "SkillGap", 0.6, 30)

local sec2 = info(Color3.fromRGB(110, 118, 138))
sec2.Text = "— 状态 —"
statusLbl = info(Color3.fromRGB(150, 200, 255))
statusLbl.Text = "状态 — · 待机"
pathLbl = info(Color3.fromRGB(110, 118, 138))
pathLbl.Text = primaryOk
	and "走游戏输入回调（推荐）"
	or (hasConn and "找不到 FishingPrimary，抛竿不可用" or "缺 getconnections，退化为直发包（抛竿不可用）")

local tip = info(Color3.fromRGB(110, 118, 138))
tip.Text = "完美区 >= 0.8769(x10) · 收线上限 6 CPS · QTE 快于 0.1s 会被记"

local exitBtn = row("退出并清理脚本", "__exit", false)
exitBtn.Text = "点我退出"

-- 拖拽
local dragStart, startPos, dragActive, dragging
local function endDrag()
	dragActive = false
	dragging = false
end
panel.InputBegan:Connect(function(i)
	if i.UserInputType ~= Enum.UserInputType.MouseButton1 and i.UserInputType ~= Enum.UserInputType.Touch then
		return
	end
	local bp = body.AbsolutePosition
	local bs = body.AbsoluteSize
	if i.Position.X >= bp.X and i.Position.X <= bp.X + bs.X
		and i.Position.Y >= bp.Y and i.Position.Y <= bp.Y + bs.Y then
		return
	end
	dragStart = i.Position
	startPos = panel.Position
	dragActive = true
	dragging = false
end)
panel.InputEnded:Connect(endDrag)
track(UIS.InputChanged:Connect(function(i)
	if not dragActive then
		return
	end
	local d = i.Position - dragStart
	if not dragging and d.Magnitude > 6 then
		dragging = true
	end
	if dragging then
		panel.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
	end
end))
track(UIS.TouchMoved:Connect(function(i)
	if not dragActive then
		return
	end
	local d = i.Position - dragStart
	if not dragging and d.Magnitude > 6 then
		dragging = true
	end
	if dragging then
		panel.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
	end
end))

local collapsed = false
mini.MouseButton1Click:Connect(function()
	collapsed = not collapsed
	mini.Text = collapsed and "+" or "—"
	TWS:Create(panel, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {
		Size = UDim2.new(0, WIDE, 0, collapsed and BAR or 360),
	}):Play()
	body.Visible = not collapsed
end)

print("[Diaoyu] 已加载 · FishingController / RodController 就位")

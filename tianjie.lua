local RS = game:GetService("ReplicatedStorage")
local TWS = game:GetService("TweenService")
local UIS = game:GetService("UserInputService")
-- VirtualUser / VirtualInputManager 在某些执行器上取不到，
-- 顶层不加 pcall 会直接让整个脚本报错退出，分享出去别人就用不了。
local VU, VIM
pcall(function()
	VU = game:GetService("VirtualUser")
end)
pcall(function()
	VIM = game:GetService("VirtualInputManager")
end)
local LP = game:GetService("Players").LocalPlayer
local PG = LP:WaitForChild("PlayerGui")

local GEN = (getgenv().__TianjieGen or 0) + 1
getgenv().__TianjieGen = GEN
local function alive()
	return getgenv().__TianjieGen == GEN
end

-- 挂在游戏对象上的连接不会随 GUI 销毁，退出时要手动断，先登记起来。
-- 界面自身的连接绑在会被 Destroy 的实例上，不用登记。
local conns = {}

local function track(c)
	if c then
		conns[#conns + 1] = c
	end
	return c
end

local CS = RS.Packages.Knit.Services.CultivationService
local BS = RS.Packages.Knit.Services.BossService
local DS = RS.Packages.Knit.Services.DungeonService
local RF, RE = CS.RF, CS.RE

local CFG = {
	Breakthrough = false,
	Refine = false,
	Talent = false,
	Ascend = false,
	Meditate = false,
	Daily = false,
	Casket = false,
	Books = false,
	Pill = false,
	JoinSect = false,
	SectMulti = false,
	SectRotateMin = 10,
	Sects = { voidcourt = true },
	Spar = false,
	Mission = false,
	Promote = false,
	Manual = false,
	Room = false,
	Roll = false,
	OnlyChaos = false,
	AutoRoll = false,
	AutoDivine = false,
	AutoSpar = false,
	RollTarget = "chaos",
	Bloodline = false,
	Divine = false,
	Boss = false,
	Explore = false,
	ExploreStage = "village",
	TapRate = 0.1,
	Hell = false,
	HellDiff = "normal",
	HellAuto = true,
	HellPick = 1,
	HellAgain = 6,
	HellFreshOnly = true,
	HellMarket = false,
	HellBuy = "h_sbe_100",
	HellReserve = 0,
	AntiAFK = false,
	AutoClaimAFK = false,
	AFKClaimMin = 900,
	Heartbeat = 25,
	Difficulty = "easy",
	AscendRank = 3,
	AscendMinStage = 0,
	AscendEvery = 2,
	Reserve = 15000,
	CasketCap = 10,
	Slot = 0,
}

-- 宗门表，id 与 MS-Sects.lua 对齐；最后一个长老位是宗门首领。
local SECTS = {
	{ id = "azure", name = "云宗", elders = { "azure_gate", "azure_hall", "azure_head", "azure_leader" } },
	{ id = "stonecloud", name = "石云寺", elders = { "stone_novice", "stone_carver", "stone_abbot", "stonecloud_leader" } },
	{ id = "thunder", name = "雷峰宗", elders = { "thunder_warden", "thunder_elder", "thunder_peak", "thunder_leader" } },
	{ id = "irongate", name = "铁门堡", elders = { "iron_sentry", "iron_captain", "iron_commander", "irongate_leader" } },
	{ id = "taoist", name = "仙道宗", elders = { "taoist_scribe", "taoist_sword", "taoist_patriarch", "taoist_leader" } },
	{ id = "frostpeak", name = "霜峰殿", elders = { "frost_watch", "frost_elder", "frost_lord", "frostpeak_leader" } },
	{ id = "nineheavens", name = "九霄宫", elders = { "nine_herald", "nine_marshal", "nine_sovereign", "nineheavens_leader" } },
	{ id = "bloodmoon", name = "血月阁", elders = { "blood_usher", "blood_elder", "blood_master", "bloodmoon_leader" } },
	{ id = "chaos", name = "混沌庭", elders = { "chaos_warden", "chaos_ancestor", "chaos_nameless", "chaos_leader" } },
	{ id = "voidcourt", name = "虚无庭", elders = { "void_page", "void_arbiter", "void_seat", "voidcourt_leader" } },
}

local function sectById(id)
	for _, v in ipairs(SECTS) do
		if v.id == id then
			return v
		end
	end
end

-- 地狱门：10 只兽按 rank 顺序解锁，第 N 只要第 N-1 只至少赢过 1 次（任意难度）。
-- id 与 MS-Hell.lua 的 "hell_"..rank 对齐，名字取那里的 hanzi。
local HELL_BEASTS = {
	{ rank = 1, id = "hell_1", name = "灰犬" },
	{ rank = 2, id = "hell_2", name = "燼豬" },
	{ rank = 3, id = "hell_3", name = "血豹" },
	{ rank = 4, id = "hell_4", name = "鐵蜥" },
	{ rank = 5, id = "hell_5", name = "魂蠍" },
	{ rank = 6, id = "hell_6", name = "獄獅" },
	{ rank = 7, id = "hell_7", name = "獄犬" },
	{ rank = 8, id = "hell_8", name = "焰鳳" },
	{ rank = 9, id = "hell_9", name = "淵蛇" },
	{ rank = 10, id = "hell_10", name = "獄龍" },
}

-- 四试炼，倍率取自 MS-Hell 的 essence 字段
local HELL_DIFFS = { "easy", "normal", "hard", "nightmare" }

-- 地狱市场可反复买的只有精华（蛋是解锁用的一次性品），成本即数字本身
local HELL_BUYS = { "h_sbe_100", "h_sbe_1000", "h_sbe_10000" }
local HELL_BUY_COST = { h_sbe_100 = 100, h_sbe_1000 = 1000, h_sbe_10000 = 10000 }

local function hellUnlocked(clears, rank)
	if rank <= 1 then
		return true
	end
	local prev = HELL_BEASTS[rank - 1]
	return prev ~= nil and (tonumber((clears or {})[prev.id]) or 0) >= 1
end

-- 已解锁的最深一层，用来挑精华最高的目标
local function hellDeepest(clears)
	local best = 1
	for _, b in ipairs(HELL_BEASTS) do
		if hellUnlocked(clears, b.rank) then
			best = b.rank
		else
			break
		end
	end
	return best
end

local function rankOf(id)
	for _, b in ipairs(HELL_BEASTS) do
		if b.id == id then
			return b.rank
		end
	end
end

-- 失败的层不永久封死，只冷却一段时间再允许重试；否则一旦某层被误判失败，
-- 就再也爬不上去了。只存在本次会话里，重跑脚本自动恢复干净状态。
local HELL_RETRY_SECS = 180
local hellRetryAt = {}

-- 早先的版本把「打不过的层」持久化在 getgenv 里，bug 期间攒下了脏数据、
-- 而且重跑脚本也不会清。这里主动删掉那个键，免得旧标记继续压着层数。
pcall(function()
	local g = _G
	if type(getgenv) == "function" and type(getgenv()) == "table" then
		g = getgenv()
	end
	if g.__TianjieHellBlocked ~= nil then
		g.__TianjieHellBlocked = nil
	end
end)

local function hellCooling(rank)
	local t = hellRetryAt[rank]
	return t ~= nil and os.clock() < t
end

local function hellFail(rank)
	if rank then
		hellRetryAt[rank] = os.clock() + HELL_RETRY_SECS
	end
end

-- 选中宗门，保持 SECTS 的固定顺序，轮流时次序才稳定
local function sectPicks()
	local out = {}
	for _, v in ipairs(SECTS) do
		if CFG.Sects[v.id] then
			out[#out + 1] = v.id
		end
	end
	return out
end

-- 长老按当前所在宗门取，否则会对着别的宗门 id 白打
local function eldersOf(sect)
	local def = sectById(sect or "") or sectById("voidcourt")
	return def.elders
end
local RANKS = { "Outer", "Inner", "Inherited", "Retinue", "Custodian", "Hall Master" }
local MANUALS = { "sm_hall", "sm_vault", "sm_tide", "sm_pillar", "sm_channel", "sm_breath" }
local MISSIONS = { "patrol", "hall", "archive" }
local DIFFS = { "easy", "normal", "mid", "hard", "nightmare", "destruction" }
local ROLL_TARGETS = { "mortal", "earth", "heaven", "divine", "chaos" }
local STAGES = { "village", "fields", "falls", "temple", "gate", "ember", "terraces" }
local TIERS = { mortal = 1, earth = 2, heaven = 3, divine = 4, chaos = 5 }

local last = {}
local hbMode = "idle"
local hbAt = 0
local afkSince = 0
local lastClaim = 0
local inFight = false
local dungeonFight = false
local hellFight = false
local fightAt = 0
local dodgeId = nil
local hellSeen = nil
local hellRank = nil
local hellWins = 0
local ascendCount = 0
local ascendLbl, rollLbl, afkLbl, statLbl, exploreLbl, hellLbl, hellTipLbl
local hellWhy = nil

local function gate(key, secs)
	local t = os.clock()
	if not last[key] or t - last[key] > secs then
		last[key] = t
		return true
	end
	return false
end

local function call(fn, ...)
	local args = { ... }
	task.spawn(function()
		pcall(function()
			fn(unpack(args))
		end)
	end)
end

local function State()
	local ok, s = pcall(function()
		return RF.GetState:InvokeServer()
	end)
	if ok and type(s) == "table" then
		return s
	end
end

local function Cost(slot)
	return 100 * (3 ^ ((slot or 1) - 1))
end

local function TierOf(r)
	return type(r) == "table" and r.tier or nil
end

local function rootAt(s, slot)
	local roots = type(s) == "table" and s.roots or nil
	if type(roots) ~= "table" or not slot then
		return nil
	end
	return roots[slot] or roots[tostring(slot)] or roots[tonumber(slot)]
end

local function better(new, old)
	if type(new) ~= "table" then
		return false
	end
	if type(old) ~= "table" then
		return true
	end
	local a = TIERS[new.tier] or 0
	local b = TIERS[old.tier] or 0
	if a ~= b then
		return a > b
	end
	return (tonumber(new.mult) or 0) > (tonumber(old.mult) or 0)
end

-- 只认服务端写的 CultRealmIndex。原实现还会拿 CultTitle 里的 "Nth Layer"
-- 当境界用，那是境界内的层数(1-9)，不是境界，比阈值必然误判。
local function curRealm()
	local a = LP:GetAttribute("CultRealmIndex")
	if type(a) == "number" then
		return a
	end
	return nil
end

local function PickSlot(s)
	if CFG.Slot > 0 then
		return CFG.Slot
	end
	local roots = s.roots or {}
	local pick, low = 0, 99
	for i = 1, (s.slots or 1) do
		local rk = TIERS[TierOf(roots[i])] or 0
		if rk < low then
			pick, low = i, rk
		end
	end
	if low >= (TIERS[CFG.WantTier or "chaos"] or 5) then
		return 0
	end
	return pick
end

local function anyOn()
	for _, k in ipairs({ "Breakthrough", "Refine", "Talent", "Ascend", "Meditate", "Daily", "Casket", "Books", "Pill", "JoinSect", "Spar", "Mission", "Promote", "Manual", "Room", "Roll", "Bloodline", "Divine", "AutoRoll", "AutoDivine", "AutoSpar", "Boss", "Explore", "AntiAFK", "AutoClaimAFK" }) do
		if CFG[k] then
			return true
		end
	end
	return false
end

local function hideRootUI()
	local ui = PG:FindFirstChild("AscensionUI")
	if not ui then
		return
	end
	local root = ui:FindFirstChild("Root")
	local content = root and root:FindFirstChild("Content")
	if content then
		for _, nm in ipairs({ "Roots", "Root", "SpiritRoots" }) do
			local f = content:FindFirstChild(nm)
			if f and f.Visible then
				f.Visible = false
			end
		end
	end
	for _, nm in ipairs({ "BundleReveal", "Reveal", "RollReveal" }) do
		local f = ui:FindFirstChild(nm)
		if f and f.Visible then
			f.Visible = false
		end
	end
end

local hasMouseRel = type(mousemoverel) == "function"
local function heartbeat()
	if hasMouseRel then
		pcall(mousemoverel, 1, 0)
		pcall(mousemoverel, -1, 0)
		hbMode = "mousemove"
		return
	end
	local ok = pcall(function()
		if type(mousemoveabs) == "function" then
			mousemoveabs(2, 2)
			mousemoveabs(1, 1)
		end
	end)
	if ok then
		hbMode = "moveabs"
		return
	end
	pcall(function()
		VU:CaptureController()
		VU:ClickButton2(Vector2.new(0, 0))
	end)
	hbMode = "VirtualUser"
end

track(LP.Idled:Connect(function()
	if not CFG.AntiAFK then
		return
	end
	pcall(function()
		VU:CaptureController()
		VU:ClickButton2(Vector2.new())
	end)
	hbAt = os.clock()
end))

task.spawn(function()
	while alive() do
		if CFG.AntiAFK and os.clock() - hbAt >= (CFG.Heartbeat or 25) then
			hbAt = os.clock()
			heartbeat()
			call(RF.AfkPing.InvokeServer, RF.AfkPing)
		end
		task.wait(1)
	end
end)

task.spawn(function()
	while alive() do
		local s = State()
		if s then
			local isAfk = type(s.afkSnapshot) == "table" or s.afkSnapshot == true
			if isAfk and afkSince == 0 then
				afkSince = os.clock()
			elseif not isAfk then
				afkSince = 0
			end
			if CFG.AutoClaimAFK and isAfk and afkSince > 0 then
				local held = os.clock() - afkSince
				if held >= (CFG.AFKClaimMin or 900) and os.clock() - lastClaim > 60 then
					lastClaim = os.clock()
					afkSince = 0
					call(RF.EndAfk.InvokeServer, RF.EndAfk)
				end
			end
			if afkLbl then
				afkLbl.Text = isAfk and ("挂机中 %ds"):format(math.floor(os.clock() - afkSince)) or "未挂机"
			end
		end
		task.wait(2)
	end
end)

track(BS.RE.Event.OnClientEvent:Connect(function(e)
	if not alive() or type(e) ~= "table" then
		return
	end
	local k = e.kind
	if k == "telegraph" then
		dodgeId = e.id
		-- 副本野兽、独立 Boss、地狱兽共用 BossService，任一在打都要闪避
		if not (inFight or dungeonFight or hellFight) then
			return
		end
		task.spawn(function()
			local id = e.id
			if e.style == "spam" then
				for i = 1, 11 do
					if not (inFight or dungeonFight or hellFight) or dodgeId ~= id then
						return
					end
					pcall(function()
						BS.RE.Input:FireServer({ kind = "dodge", id = id })
					end)
					task.wait(0.035)
				end
			else
				task.wait((e.duration or 1.2) * 0.87)
				if (inFight or dungeonFight or hellFight) and dodgeId == id then
					pcall(function()
						BS.RE.Input:FireServer({ kind = "dodge", id = id })
					end)
				end
			end
		end)
	elseif k == "result" or k == "end" or k == "over" then
		inFight = false
	end
end))

task.spawn(function()
	while alive() do
		if CFG.Roll then
			local s = State()
			if s and type(s.pendingRoot) == "table" then
				local pslot = (tonumber(s.pendingRootSlot) or 0) > 0 and s.pendingRootSlot or PickSlot(s)
				local keep = CFG.OnlyChaos and (s.pendingRoot.tier == "chaos") or better(s.pendingRoot, rootAt(s, pslot))
				if keep then
					call(RF.ResolveRoot.InvokeServer, RF.ResolveRoot, pslot)
				else
					call(RF.DiscardRoot.InvokeServer, RF.DiscardRoot, pslot)
					task.wait(0.22)
					local chk = State()
					if chk and type(chk.pendingRoot) == "table" then
						call(RF.ResolveRoot.InvokeServer, RF.ResolveRoot, pslot)
					end
				end
			elseif s then
				hideRootUI()
				local slot = PickSlot(s)
				if slot > 0 and (tonumber(s.stones) or 0) > Cost(slot) + CFG.Reserve then
					call(RF.RollRoot.InvokeServer, RF.RollRoot, slot)
					task.wait(0.1)
					local r = State()
					local pr = r and r.pendingRoot
					if type(pr) == "table" then
						local keep = CFG.OnlyChaos and (pr.tier == "chaos") or better(pr, rootAt(s, slot))
						if keep then
							call(RF.ResolveRoot.InvokeServer, RF.ResolveRoot, slot)
						else
							call(RF.DiscardRoot.InvokeServer, RF.DiscardRoot, slot)
							task.wait(0.22)
							local chk = State()
							if chk and type(chk.pendingRoot) == "table" then
								call(RF.ResolveRoot.InvokeServer, RF.ResolveRoot, slot)
							end
						end
					end
					if rollLbl then
						rollLbl.Text = ("灵石 %s"):format(tostring(s.stones))
					end
				end
			end
		end
		task.wait(0.2)
	end
end)

-- 战斗点击统一走这里。节奏对齐 MS-Boss 的 TAP_COOLDOWN = 0.09（doTap 里
-- 0.09 秒内的重复点击会被丢掉），所以默认 0.1 秒约 10 次/秒。
-- 之前误用了 HERO_ATTACK_RELEASE = 0.3，那是动画释放窗口不是输入上限，慢了 3 倍多。
task.spawn(function()
	while alive() do
		if (CFG.Boss and inFight) or dungeonFight or hellFight then
			pcall(function()
				BS.RE.Input:FireServer({ kind = "tap" })
			end)
		end
		if inFight and os.clock() - fightAt > 320 then
			inFight = false
		end
		-- 打超过 MAX_SECONDS 判卡住，否则会一直点着不走位
		if dungeonFight and os.clock() - fightAt > 300 then
			dungeonFight = false
		end
		if hellFight and os.clock() - fightAt > 300 then
			hellFight = false
		end
		task.wait(math.max(0.09, tonumber(CFG.TapRate) or 0.1))
	end
end)

task.spawn(function()
	while alive() do
		if CFG.Manual then
			for _, id in ipairs(MANUALS) do
				for i = 1, 40 do
					local ok, r = pcall(function()
						return RF.UpgradeSectManual:InvokeServer(id)
					end)
					if not ok or r == nil or r == false then
						break
					end
					task.wait(0.08)
				end
				task.wait(0.2)
			end
		end
		task.wait(3)
	end
end)

local autoRollOn = false

local function syncAutoRoll(want, stones)
	local on = want and (tonumber(stones) or 0) > CFG.Reserve
	if on ~= autoRollOn then
		autoRollOn = on
		pcall(function()
			RF.SetAutoState:InvokeServer("roll", on, CFG.RollTarget)
		end)
	end
end

local dungeonAt = 0

local function ascUI()
	return PG:FindFirstChild("AscensionUI")
end

-- 地狱战和副本兽战都由 BossUI 驱动，它是 AscensionUI 的子节点。
-- 地狱开战靠设 BossUI 的 Hell 属性，结果从 HellResult 属性回读。
local function bossUI()
	local ui = ascUI()
	if not ui then
		return nil
	end
	local b = ui:FindFirstChild("BossUI")
	if b then
		return b
	end
	for _, d in ipairs(ui:GetDescendants()) do
		if d.Name == "BossUI" then
			return d
		end
	end
end

local function uiClick(b)
	if not b then
		return
	end
	pcall(function()
		if type(firesignal) == "function" then
			firesignal(b.MouseButton1Click)
			return
		end
		if type(getconnections) == "function" then
			for _, c in ipairs(getconnections(b.MouseButton1Click)) do
				c:Fire()
			end
		end
	end)
end

local function findBtn(root, name)
	if not root then
		return nil
	end
	for _, x in ipairs(root:GetDescendants()) do
		if x.Name == name and x:IsA("GuiButton") and x.Visible then
			return x
		end
	end
end

local function tryEnterDungeon()
	local ui = ascUI()
	if not ui then
		return false
	end
	local exp = ui:FindFirstChild("Explore")
	if not (exp and exp.Visible) then
		uiClick(findBtn(ui.Root, "Explore"))
		task.wait(0.5)
		exp = ui:FindFirstChild("Explore")
	end
	if not exp then
		return false
	end
	uiClick(findBtn(exp, CFG.ExploreStage))
	task.wait(0.7)
	for _, d in ipairs(exp:GetDescendants()) do
		if d:IsA("TextButton") and d.Visible and d.Text:upper():find("CHALLENGE") then
			uiClick(d)
			return true
		end
	end
	return false
end

local visitedTiles = {}

local function gridOf(name)
	local kind, x, y = name:match("^(%a+)_(%d+)_(%d+)$")
	return kind, tonumber(x), tonumber(y)
end

local function clickAt(x, y, floor)
	if floor and type(firesignal) == "function" then
		local ok = pcall(firesignal, floor.InputBegan, {
			UserInputType = Enum.UserInputType.MouseButton1,
			UserInputState = Enum.UserInputState.Begin,
			Position = Vector3.new(x, y, 0),
			Delta = Vector3.new(0, 0, 0),
		})
		if ok then
			return
		end
	end
	pcall(function()
		if type(mousemoveabs) == "function" then
			mousemoveabs(x, y)
		end
		if type(mouse1click) == "function" then
			mouse1click(x, y)
		end
	end)
end

local function walkStep(d)
	local world = d:FindFirstChild("World")
	local hero = world and world:FindFirstChild("Hero")
	local tiles = world and world:FindFirstChild("Tiles")
	if not hero or not tiles then
		return false
	end
	local hx = hero.AbsolutePosition.X + hero.AbsoluteSize.X / 2
	local hy = hero.AbsolutePosition.Y + hero.AbsoluteSize.Y / 2
	local cell = 0
	for _, t in ipairs(tiles:GetChildren()) do
		if t.AbsoluteSize.X > 0 then
			cell = t.AbsoluteSize.X
			break
		end
	end
	if cell <= 0 then
		cell = 40
	end
	local function distOf(t)
		local cx = t.AbsolutePosition.X + t.AbsoluteSize.X / 2
		local cy = t.AbsolutePosition.Y + t.AbsoluteSize.Y / 2
		return math.sqrt((cx - hx) ^ 2 + (cy - hy) ^ 2), cx, cy
	end
	local function pick(wantKind)
		local best, bd, bx, by = nil, 1e9, 0, 0
		for _, t in ipairs(tiles:GetChildren()) do
			if not visitedTiles[t.Name] then
				local kind = t.Name:match("^(%a+)_")
				if not wantKind or kind == wantKind then
					local dist, cx, cy = distOf(t)
					if dist > cell * 0.55 and dist < cell * 1.75 and dist < bd then
						bd, best, bx, by = dist, t, cx, cy
					end
				end
			end
		end
		return best, bx, by
	end
	local best, bx, by = pick("Chest")
	if not best then
		best, bx, by = pick(nil)
	end
	if not best then
		visitedTiles = {}
		best, bx, by = pick(nil)
	end
	if not best then
		return false
	end
	visitedTiles[best.Name] = true
	clickAt(bx, by, d:FindFirstChild("Floor"))
	return true
end

local openedChests = {}

local chestCount = 0
local chestStones = 0

local function openChests(d)
	local tiles = d:FindFirstChild("World") and d.World:FindFirstChild("Tiles")
	if not tiles then
		return
	end
	for _, t in ipairs(tiles:GetChildren()) do
		local x, y = t.Name:match("^Chest_(%d+),(%d+)$")
		if x and not openedChests[t.Name] then
			local ok, r = pcall(function()
				return DS.RF.OpenChest:InvokeServer(tonumber(x), tonumber(y))
			end)
			-- 只在服务端确认后才记账，失败的下轮还能重试
			if ok and type(r) == "table" and r.ok then
				openedChests[t.Name] = true
				chestCount = chestCount + 1
				for _, row in ipairs(r.rows or {}) do
					if row.kind == "stones" then
						chestStones = chestStones + (tonumber(row.count) or 0)
					end
				end
			end
			if exploreLbl then
				exploreLbl.Text = ("开箱 %d · 灵石 +%d"):format(chestCount, chestStones)
			end
			return
		end
	end
end

task.spawn(function()
	while alive() do
		if CFG.Explore then
			local ui = ascUI()
			local d = ui and ui:FindFirstChild("Dungeon")
			if d and d.Visible then
				if dungeonAt == 0 then
					dungeonAt = os.clock()
					visitedTiles = {}
					openedChests = {}
				end
				openChests(d)
				local bossUI = (ui and ui:FindFirstChild("BossUI")) or d:FindFirstChild("BossUI", true)
				if bossUI and bossUI.Visible then
					-- 只置位，点击交给上面 0.3 秒的统一循环。
					-- 打输会被服务端判 "The loot is lost." 清掉整趟箱子，
					-- 所以这里绝不能再按 1.2 秒摸鱼。
					if not dungeonFight then
						dungeonFight = true
						fightAt = os.clock()
					end
				else
					dungeonFight = false
					walkStep(d)
				end
				if os.clock() - dungeonAt > 240 and not dungeonFight then
					-- 战斗中不离开，中途退会把这趟箱子丢掉
					call(DS.RF.Leave.InvokeServer, DS.RF.Leave)
					dungeonAt = 0
					dungeonFight = false
					task.wait(3)
				end
			else
				dungeonAt = 0
				dungeonFight = false
				local ok, st = pcall(function()
					return DS.RF.GetState:InvokeServer()
				end)
				local tries = (ok and type(st) == "table") and tonumber(st.tries) or 0
				if exploreLbl then
					exploreLbl.Text = ("探索次数 %s"):format(tostring(tries))
				end
				if tries > 0 and gate("explore", 25) then
					tryEnterDungeon()
				end
			end
		end
		task.wait(1.2)
	end
end)

-- 战斗结束会停在结果界面（u5 = "result"），必须点掉它的 Close 才会继续：
-- backToStart() 是唯一写出 HellResult 的地方，也把 u5 复位成 "closed"。
-- 不点的话拿不到结果、openHell 也会因为 u5 ~= "closed" 直接 return，下一场发不出去。
local function tryCloseResult()
	local b = bossUI()
	if not b then
		return false
	end
	local res = b:FindFirstChild("Result")
	if not (res and res:IsA("GuiObject") and res.Visible) then
		return false
	end
	local close = res:FindFirstChild("Close")
	if close and close:IsA("GuiButton") then
		uiClick(close)
		return true
	end
	return false
end

-- 拒绝原因和剩余次数都写在 BossUI.Start.Status 上，游戏自己也是从那儿 warn 的。
-- 直接读出来显示，省得去翻 Output。（必须放在 bossUI 之后）
local function fightStatusText()
	local b = bossUI()
	if not b then
		return nil
	end
	local st = b:FindFirstChild("Start")
	st = st and st:FindFirstChild("Status")
	local txt = st and st.Text
	if type(txt) == "string" and txt ~= "" then
		return txt
	end
	return nil
end

-- 地狱门战斗。开战方式是给 BossUI 设 Hell 属性（原版 UI 就是这么发的），
-- 不是直接调 remote。结果从 HellResult 回读，值会变所以用轮询比对。
-- 打输会被服务端记为 lost：本局把目标档位下调一层，不再往上顶。
task.spawn(function()
	while alive() do
		-- 我们发起的战斗结束后会停在结果界面，先点掉它。
		-- 点掉会同步走 backToStart()，HellResult 当场就有了，所以放在读属性之前，
		-- 这样同一轮就能认领结果，不用再等一秒。
		if (CFG.Hell and hellFight) or (CFG.Boss and inFight) then
			tryCloseResult()
		end
		if CFG.Hell then
				local s = State()
				local b = bossUI()
				if s and b then
					local res = b:GetAttribute("HellResult")

					if hellFight then
						local ended = res ~= hellSeen
						-- 发起后迟迟没有任何结果回来，说明这场根本没被受理
						local lost = fightAt > 0 and os.clock() - fightAt > 60
						if ended then
							hellSeen = res
							local id, grade
							if type(res) == "string" then
								-- "<兽id>:<won|lost|fled>:<结束时间戳>"
								id, grade = res:match("^([^:]+):(%a+):%d+$")
							end
							local r = id and rankOf(id) or nil
							if r then
								hellFight = false
								if grade == "won" then
									hellWins = hellWins + 1
									if CFG.HellAuto then
										-- 封顶在第 10 层：再往上就没有兽了，越界会让整个
										-- 自动化停摆（连刷精华都不做）。到顶就一直刷第 10 层。
										hellRank = math.min(r + 1, #HELL_BEASTS)
										print(("[Tianjie] 地狱 %s 赢 -> 下一层 %d"):format(id, hellRank))
									else
										print(("[Tianjie] 地狱 %s 赢（手动指定，继续打它）"):format(id))
									end
								else
									hellWhy = fightStatusText()
									print(("[Tianjie] 地狱 %s 判定 %s%s"):format(
										id,
										tostring(grade),
										hellWhy and (" · 原因: " .. hellWhy) or ""
									))
									-- 「次数用完」不是这层打不过，别因此把层级降下来，
									-- 否则次数一耗尽就会一路退到第1层，白丢进度。
									local noTries = type(hellWhy) == "string"
										and string.find(string.lower(hellWhy), "tries", 1, true) ~= nil
									if not noTries then
										hellFail(r)
										if CFG.HellAuto then
											hellRank = math.max(1, r - 1)
										end
									end
								end
							else
								print(("[Tianjie] 地狱结果解析失败: %s"):format(tostring(res)))
							end
						elseif lost then
							hellFight = false
							local t = HELL_BEASTS[hellRank or 0]
							if t then
								print(("[Tianjie] 地狱 %s 发起后 60 秒无结果 -> 冷却该层"):format(t.id))
								hellFail(t.rank)
								if CFG.HellAuto then
									hellRank = math.max(1, t.rank - 1)
								end
							end
						end
					else
						-- 没在打的时候只同步，不认领任何结果
						hellSeen = res
					end

					local clears = s.hellClears or {}
					local fresh = tonumber(s.hellFreshLeft) or 0

					-- 地狱和独立 Boss 共用同一份次数预算。次数用完时服务端会直接拒绝
					-- Begin（"No tries left. They return in MM:SS."），所以先看次数，
					-- 别去撞墙。字段缺失时按"有次数"处理，免得老版本状态卡死自动化。
					local tries = tonumber(s.bossTries)
					local triesMax = tonumber(s.bossTriesMax) or 10
					local readyIn = tonumber(s.bossReadyIn) or 0
					local hasTries = (tries == nil) or (tries > 0 and readyIn <= 0)

					if not CFG.HellAuto then
						-- 手动指定：就盯着点的那一只，不自动升降
						hellRank = math.max(1, math.min(tonumber(CFG.HellPick) or 1, #HELL_BEASTS))
					else
						-- 首次进入从已解锁的最深层开始试
						if hellRank == nil then
							hellRank = hellDeepest(clears)
						end
						-- 冷却中的层往下退到能打的。冷却到期就自然会重回该层，
						-- 不像以前那样永久封死（那会让某一层误判后就再也爬不上去）。
						while hellRank > 1 and hellCooling(hellRank) do
							hellRank = hellRank - 1
						end
					end

					if hellLbl then
						local t = HELL_BEASTS[hellRank]
						local suffix = ""
						if not CFG.HellAuto then
							-- 手动指定了没解锁的兽时要说出来，否则看着像没反应
							suffix = (t and not hellUnlocked(clears, t.rank)) and "(未解锁)" or "(手动)"
						end
						local tryTxt
						if tries == nil then
							tryTxt = "次数?"
						elseif hasTries then
							tryTxt = ("次数%d/%d"):format(tries, triesMax)
						else
							tryTxt = ("次数0·%d:%02d后恢复"):format(readyIn // 60, readyIn % 60)
						end
						hellLbl.Text = ("地狱 %d 胜 · 打%s%s · %s · 5倍剩%d"):format(
							hellWins,
							t and ("%d.%s"):format(t.rank, t.name) or "?",
							suffix,
							tryTxt,
							fresh
						)
					end
					if hellTipLbl then
						-- 被拒的原因 / 剩余次数原本只在 Output 里，这里直接摆出来
						hellTipLbl.Text = hellWhy and ("上次被拒: " .. hellWhy)
							or "点下面名字=指定打它 · 自动模式会打赢往深爬、打输降层"
					end

					local canGo = hasTries and ((not CFG.HellFreshOnly) or fresh > 0)
					if canGo and not hellFight and gate("hell", math.max(2, CFG.HellAgain or 6)) then
						local target = HELL_BEASTS[hellRank]
						-- 冷却中的层先不发：手动指定时也一样，避免对着打不了的层硬刷
						if target and not hellCooling(hellRank) and hellUnlocked(clears, hellRank) then
							-- 先把当前结果同步掉，这样之后的变化一定是这一场产生的，
							-- 不会把上一场的残留结果误认成这一场的。
							hellSeen = res
							-- 末尾这个数字必须每次都变：游戏端靠 GetAttributeChangedSignal("Hell")
							-- 感知开战，值不变就不会触发。
							local nonce = math.floor(os.clock() * 1000)
							local ok = pcall(function()
								b:SetAttribute("Hell", ("%s:%s:%d"):format(
									target.id,
									CFG.HellDiff or "normal",
									nonce
								))
							end)
							if ok then
								hellFight = true
								fightAt = os.clock()
								print(("[Tianjie] 地狱发起 %s:%s"):format(target.id, CFG.HellDiff or "normal"))
							end
					end
				end
			end
		elseif hellFight then
			hellFight = false
		end
		task.wait(1)
	end
end)

-- 地狱市场。HellTrade 挂在 BossService 上，不是 CultivationService。
task.spawn(function()
	while alive() do
		if CFG.HellMarket then
			local s = State()
			if s then
				local id = CFG.HellBuy or "h_sbe_100"
				local cost = HELL_BUY_COST[id] or 100
				local essence = tonumber(s.hellEssence) or 0
				if essence >= cost + (tonumber(CFG.HellReserve) or 0) and gate("hellbuy", 8) then
					call(BS.RF.HellTrade.InvokeServer, BS.RF.HellTrade, id)
				end
			end
		end
		task.wait(2)
	end
end)

task.spawn(function()
	while alive() do
		local s = anyOn() and State() or nil
		if s then
			if CFG.JoinSect then
				local picks = sectPicks()
				local cur = s.sect
				if #picks > 0 then
					if not (cur and CFG.Sects[cur]) then
						-- 不在选中的宗门里，进第一个
						if gate("join", 30) then
							call(RF.JoinSect.InvokeServer, RF.JoinSect, picks[1])
						end
					elseif CFG.SectMulti and #picks > 1 and gate("sectrotate", math.max(1, CFG.SectRotateMin or 10) * 60) then
						-- 轮流模式：待够时间就换下一个
						local i = table.find(picks, cur) or 1
						call(RF.JoinSect.InvokeServer, RF.JoinSect, picks[(i % #picks) + 1])
					end
				end
			end

			if CFG.Spar and s.sect then
				local cd = s.elderCooldowns or {}
				for _, e in ipairs(eldersOf(s.sect)) do
					if (tonumber(cd[e]) or 0) <= 0 then
						call(RF.ChallengeElder.InvokeServer, RF.ChallengeElder, e)
						task.wait(0.3)
					end
				end
			end

			if CFG.Breakthrough and gate("bt", 5) then
				call(RF.BreakthroughMax.InvokeServer, RF.BreakthroughMax)
			end

			if CFG.Mission and s.sect then
				local m = s.sectMissions or {}
				for _, id in ipairs(MISSIONS) do
					local v = m[id]
					if v == nil then
						call(RF.StartMission.InvokeServer, RF.StartMission, id)
						task.wait(0.3)
					elseif type(v) == "number" and v <= (tonumber(s.serverTime) or os.time()) then
						call(RF.ClaimMission.InvokeServer, RF.ClaimMission, id)
						task.wait(0.3)
					end
				end
			end

			if CFG.Promote and gate("promote", 20) and (tonumber(s.sectRank) or 1) < CFG.AscendRank then
				call(RF.Promote.InvokeServer, RF.Promote)
			end

			if CFG.Refine and gate("refine", 3) then
				call(RF.RefineFleshMax.InvokeServer, RF.RefineFleshMax)
			end

			if CFG.Talent and gate("talent", 2) then
				call(RF.RollTalent.InvokeServer, RF.RollTalent)
			end

			if CFG.AutoRoll or autoRollOn then
				syncAutoRoll(CFG.AutoRoll, s.stones)
				if rollLbl then
					rollLbl.Text = ("灵石 %s%s"):format(tostring(s.stones), autoRollOn and " · 自动抽根中" or "")
				end
			end

			if CFG.AutoDivine then
				local au = s.automations or {}
				if not au.autodivine and gate("autodivine", 60) then
					call(RF.BuyAutomation.InvokeServer, RF.BuyAutomation, "autodivine")
				end
			end

			if CFG.AutoSpar then
				local au = s.automations or {}
				if not au.autospar and gate("autospar", 60) then
					call(RF.BuyAutomation.InvokeServer, RF.BuyAutomation, "autospar")
				end
			end

			if CFG.Room and gate("room", 20) and (tonumber(s.sectRoomReady) or 0) > 0 then
				call(RF.EnterCultivationRoom.InvokeServer, RF.EnterCultivationRoom)
			end

			if CFG.Meditate and gate("meditate", 10) and (tonumber(s.meditateLeft) or 0) > 0 then
				call(RF.Meditate.InvokeServer, RF.Meditate)
			end

			if CFG.Daily and gate("daily", 300) then
				call(RF.ClaimDaily.InvokeServer, RF.ClaimDaily)
			end

			if CFG.Books and gate("books", 120) then
				call(RF.UseAllBooks.InvokeServer, RF.UseAllBooks)
			end

			if CFG.Pill and gate("pill", 60) then
				call(RF.UsePill.InvokeServer, RF.UsePill)
			end

			if CFG.Bloodline and gate("blood", 5) then
				if type(s.pendingBloodline) == "string" then
					call(RF.ResolveBloodline.InvokeServer, RF.ResolveBloodline)
				elseif (tonumber(s.bloodlineSpins) or 0) > 0 then
					call(RF.SpinBloodline.InvokeServer, RF.SpinBloodline)
				end
			end

			if CFG.Divine and gate("divine", 5) then
				if s.pendingDivineBody then
					call(RF.ResolveDivineBody.InvokeServer, RF.ResolveDivineBody)
				elseif (tonumber(s.divineSpins) or 0) > 0 then
					call(RF.SpinDivineBody.InvokeServer, RF.SpinDivineBody)
				end
			end

			if CFG.Casket and gate("casket", 10) then
				local stock = type(s.shopStock) == "table" and (tonumber(s.shopStock["casket_silk"]) or 0) or 0
				local afford = math.floor((tonumber(s.stones) or 0) / 100)
				local qty = math.min(stock, afford, CFG.CasketCap)
				if qty > 0 then
					call(RF.BuyItem.InvokeServer, RF.BuyItem, "casket_silk", qty)
				end
			end

			if CFG.Boss and not inFight and gate("boss", 8) then
				if (tonumber(s.bossTries) or 0) > 0 and (tonumber(s.bossReadyIn) or 0) <= 0 then
					local ok = pcall(function()
						BS.RF.Begin:InvokeServer(CFG.Difficulty)
					end)
					if ok then
						inFight = true
						fightAt = os.clock()
					end
				end
			end

			if CFG.Ascend and s.canAscend and gate("ascend", math.max(0.5, CFG.AscendEvery or 2)) then
				-- canAscend 是服务端算好的，权威。境界门槛默认 0 = 不再额外卡。
				local minRealm = tonumber(CFG.AscendMinStage) or 0
				local realm = curRealm()
				if realm == nil then
					realm = math.floor((tonumber(s.stageIndex) or 0) / 9) + 1
				end
				if minRealm <= 0 or realm >= minRealm then
					call(RF.Ascend.InvokeServer, RF.Ascend)
					ascendCount = ascendCount + 1
					if ascendLbl then
						ascendLbl.Text = ("重生 %d 次"):format(ascendCount)
					end
				end
			end

			if statLbl then
				statLbl.Text = ("灵石 %s · 境界 %s · %s"):format(
					tostring(s.stones or "?"),
					tostring(s.realm or "?"),
					hbMode
				)
			end
		end
		task.wait(1)
	end
end)

local old = PG:FindFirstChild("TianjieHub")
if old then
	old:Destroy()
end

local gui = Instance.new("ScreenGui")
gui.Name = "TianjieHub"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder = 999999
gui.Parent = PG

-- 退出并清理：停掉所有循环、断开挂在游戏对象上的连接、销毁界面、清掉暴露的全局。
-- 关键点是 __TianjieGen 只能往上加、不能置 nil —— alive() 是拿它与自己捕获的 GEN
-- 比对，置 nil 会让下一个实例拿到相同的 GEN，已经死掉的旧实例会被"复活"。
local function shutdown()
	pcall(function()
		local g = getgenv()
		if type(g) == "table" then
			g.__TianjieGen = (tonumber(g.__TianjieGen) or 0) + 1
		end
	end)
	local n = #conns
	for _, c in ipairs(conns) do
		pcall(function()
			c:Disconnect()
		end)
	end
	table.clear(conns)
	pcall(function()
		gui:Destroy()
	end)
	pcall(function()
		local g = getgenv()
		if type(g) == "table" then
			g.TianjieCfg = nil
			g.__TianjieHellBlocked = nil
			g._TianjieScriptUrls = nil
			g._TianjieScriptUrl = nil
		end
	end)
	print(("[Tianjie] 已退出并清理（断开 %d 个连接）"):format(n))
end

local cam = workspace.CurrentCamera
local touch = UIS.TouchEnabled and not UIS.MouseEnabled
local function uiScale()
	local vp = cam.ViewportSize
	if touch then
		return math.clamp(vp.X / 420, 0.8, 1.15)
	end
	return 1
end

local SC = uiScale()
local WIDE = math.floor(268 * SC)
local BAR = math.floor(40 * math.max(SC, 0.92))
local TABH = math.floor(30 * math.max(SC, 0.92))
local ROWH = touch and 34 or 30
local MAXBODY = math.floor(cam.ViewportSize.Y * 0.62)

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.Size = UDim2.new(0, WIDE, 0, BAR + 220)
panel.Position = UDim2.new(0, touch and 12 or 24, 0.5, -150)
panel.BackgroundColor3 = Color3.fromRGB(14, 16, 22)
panel.BackgroundTransparency = 0.04
panel.BorderSizePixel = 0
panel.ClipsDescendants = true
panel.Active = true
panel.Parent = gui
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 8)
local ps = Instance.new("UIStroke", panel)
ps.Color = Color3.fromRGB(60, 68, 90)
ps.Transparency = 0.35
ps.Thickness = 1

local bar = Instance.new("Frame")
bar.Name = "Bar"
bar.Size = UDim2.new(1, 0, 0, BAR)
bar.BackgroundColor3 = Color3.fromRGB(21, 24, 33)
bar.BorderSizePixel = 0
bar.Parent = panel
Instance.new("UICorner", bar).CornerRadius = UDim.new(0, 8)
local barFix = Instance.new("Frame", bar)
barFix.Size = UDim2.new(1, 0, 0, 8)
barFix.Position = UDim2.new(0, 0, 1, -8)
barFix.BackgroundColor3 = Color3.fromRGB(21, 24, 33)
barFix.BorderSizePixel = 0

local accent = Instance.new("Frame", bar)
accent.Size = UDim2.new(0, 3, 0, 16)
accent.Position = UDim2.new(0, 8, 0.5, -8)
accent.BackgroundColor3 = Color3.fromRGB(96, 232, 180)
accent.BorderSizePixel = 0
Instance.new("UICorner", accent).CornerRadius = UDim.new(1, 0)

local title = Instance.new("TextLabel", bar)
title.Size = UDim2.new(1, -92, 1, 0)
title.Position = UDim2.new(0, 18, 0, 0)
title.BackgroundTransparency = 1
title.Text = "天界 AUTO"
title.Font = Enum.Font.GothamBold
title.TextSize = 14
title.TextColor3 = Color3.fromRGB(228, 234, 247)
title.TextXAlignment = Enum.TextXAlignment.Left

local dot = Instance.new("Frame", bar)
dot.Size = UDim2.new(0, 7, 0, 7)
dot.Position = UDim2.new(1, -78, 0.5, -3)
dot.BackgroundColor3 = Color3.fromRGB(120, 130, 150)
dot.BorderSizePixel = 0
Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)

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
local moveBtn = iconBtn(-50, "+")

local tabBar = Instance.new("Frame", panel)
tabBar.Name = "Tabs"
tabBar.Size = UDim2.new(1, 0, 0, TABH)
tabBar.Position = UDim2.new(0, 0, 0, BAR)
tabBar.BackgroundColor3 = Color3.fromRGB(17, 20, 28)
tabBar.BorderSizePixel = 0
local tbLine = Instance.new("Frame", tabBar)
tbLine.Size = UDim2.new(1, 0, 0, 1)
tbLine.Position = UDim2.new(0, 0, 1, -1)
tbLine.BackgroundColor3 = Color3.fromRGB(45, 52, 70)
tbLine.BorderSizePixel = 0

local justDragged = 0
local moveMode = false
local TABS = {}
local tabButtons = {}
local activeTab = 1
local pages = {}

-- 页签宽度按实际数量分配，加页签不用再手改除数
local function layoutTabs()
	local n = math.max(#TABS, 1)
	for i, b in ipairs(tabButtons) do
		b.Size = UDim2.new(1 / n, 0, 1, 0)
		b.Position = UDim2.new((i - 1) / n, 0, 0, 0)
	end
end

local function addTab(name)
	local i = #TABS + 1
	TABS[i] = name
	local b = Instance.new("TextButton", tabBar)
	b.Size = UDim2.new(1 / 5, 0, 1, 0)
	b.Position = UDim2.new((i - 1) / 5, 0, 0, 0)
	b.BackgroundTransparency = 1
	b.Text = name
	b.Font = Enum.Font.GothamBold
	b.TextSize = 12
	b.TextColor3 = Color3.fromRGB(140, 150, 172)
	b.AutoButtonColor = false
	local ul = Instance.new("Frame", b)
	ul.Size = UDim2.new(0.6, 0, 0, 2)
	ul.AnchorPoint = Vector2.new(0.5, 0)
	ul.Position = UDim2.new(0.5, 0, 1, -2)
	ul.BackgroundColor3 = Color3.fromRGB(96, 232, 180)
	ul.BorderSizePixel = 0
	ul.Visible = false
	Instance.new("UICorner", ul).CornerRadius = UDim.new(1, 0)
	b.MouseButton1Click:Connect(function()
		if os.clock() - justDragged < 0.25 then
			return
		end
		activeTab = i
		for k, pg in ipairs(pages) do
			pg.Visible = k == i
		end
		for _, c in ipairs(tabBar:GetChildren()) do
			if c:IsA("TextButton") then
				local line = c:FindFirstChildOfClass("Frame")
				local on = c == b
				c.TextColor3 = on and Color3.fromRGB(236, 242, 255) or Color3.fromRGB(140, 150, 172)
				if line then
					line.Visible = on
				end
			end
		end
		relayout()
	end)
	tabButtons[i] = b
	return b
end

local bodyHost = Instance.new("Frame", panel)
bodyHost.Name = "Host"
bodyHost.Size = UDim2.new(1, 0, 0, 200)
bodyHost.Position = UDim2.new(0, 0, 0, BAR + TABH)
bodyHost.BackgroundTransparency = 1
bodyHost.BorderSizePixel = 0
bodyHost.ClipsDescendants = true

local function newPage()
	local sc = Instance.new("ScrollingFrame", bodyHost)
	sc.Size = UDim2.new(1, 0, 1, 0)
	sc.BackgroundTransparency = 1
	sc.BorderSizePixel = 0
	sc.ScrollBarThickness = touch and 5 or 8
	sc.ScrollBarImageColor3 = Color3.fromRGB(90, 100, 125)
	sc.ScrollBarImageTransparency = 0.4
	sc.ScrollingDirection = Enum.ScrollingDirection.Y
	sc.AutomaticCanvasSize = Enum.AutomaticSize.Y
	sc.CanvasSize = UDim2.new(0, 0, 0, 0)
	sc.Visible = #pages == 0
	local ll = Instance.new("UIListLayout", sc)
	ll.SortOrder = Enum.SortOrder.LayoutOrder
	ll.Padding = UDim.new(0, touch and 4 or 6)
	ll.HorizontalAlignment = Enum.HorizontalAlignment.Center
	local pd = Instance.new("UIPadding", sc)
	pd.PaddingTop = UDim.new(0, 10)
	pd.PaddingBottom = UDim.new(0, 12)
	pd.PaddingLeft = UDim.new(0, 12)
	pd.PaddingRight = UDim.new(0, 12)
	pages[#pages + 1] = sc
	return sc
end

local function Toggle(page, label, key)
	local row = Instance.new("TextButton", page)
	row.Size = UDim2.new(1, 0, 0, ROWH)
	row.BackgroundTransparency = 1
	row.Text = ""
	row.AutoButtonColor = false

	local nm = Instance.new("TextLabel", row)
	nm.Size = UDim2.new(1, -58, 1, 0)
	nm.Position = UDim2.new(0, 2, 0, 0)
	nm.BackgroundTransparency = 1
	nm.Text = label
	nm.Font = Enum.Font.Gotham
	nm.TextSize = 13
	nm.TextColor3 = Color3.fromRGB(196, 204, 220)
	nm.TextXAlignment = Enum.TextXAlignment.Left

	local track = Instance.new("Frame", row)
	track.Size = UDim2.new(0, 40, 0, 20)
	track.AnchorPoint = Vector2.new(1, 0.5)
	track.Position = UDim2.new(1, 0, 0.5, 0)
	track.BackgroundColor3 = Color3.fromRGB(50, 55, 72)
	track.BorderSizePixel = 0
	Instance.new("UICorner", track).CornerRadius = UDim.new(0, 4)

	local knob = Instance.new("Frame", track)
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
		TWS:Create(track, ti, {
			BackgroundColor3 = on and Color3.fromRGB(28, 68, 58) or Color3.fromRGB(50, 55, 72),
		}):Play()
		TWS:Create(nm, ti, {
			TextColor3 = on and Color3.fromRGB(242, 248, 255) or Color3.fromRGB(150, 158, 176),
		}):Play()
	end
	paint(false)
	row.MouseButton1Click:Connect(function()
		if os.clock() - justDragged < 0.25 then
			return
		end
		CFG[key] = not CFG[key]
		paint(true)
	end)
end

-- 宗门行的重绘登记表。单选模式点一个要顶掉其他，所以得能跨行刷新。
local sectPainters = {}

local function repaintSects()
	for _, p in ipairs(sectPainters) do
		p(false)
	end
end

local function CycleRow(page, label, get, set, width)
	local row = Instance.new("TextButton", page)
	row.Size = UDim2.new(1, 0, 0, ROWH)
	row.BackgroundTransparency = 1
	row.Text = ""
	row.AutoButtonColor = false

	local nm = Instance.new("TextLabel", row)
	nm.Size = UDim2.new(1, -(width + 14), 1, 0)
	nm.Position = UDim2.new(0, 2, 0, 0)
	nm.BackgroundTransparency = 1
	nm.Text = label
	nm.Font = Enum.Font.Gotham
	nm.TextSize = 13
	nm.TextColor3 = Color3.fromRGB(180, 188, 206)
	nm.TextXAlignment = Enum.TextXAlignment.Left

	local btn = Instance.new("TextLabel", row)
	btn.Size = UDim2.new(0, width, 0, 22)
	btn.AnchorPoint = Vector2.new(0.5, 0.5)
	btn.Position = UDim2.new(1, -(width / 2), 0.5, 0)
	btn.BackgroundColor3 = Color3.fromRGB(40, 45, 60)
	btn.BorderSizePixel = 0
	btn.Text = get()
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 11
	btn.TextColor3 = Color3.fromRGB(226, 232, 245)
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)

	row.MouseButton1Click:Connect(function()
		if os.clock() - justDragged < 0.25 then
			return
		end
		set()
		btn.Text = get()
	end)
	return btn
end

-- 宗门选择行。外关整段的自动加入，行内选具体宗门。
local function SectRow(page, def)
	local row = Instance.new("TextButton", page)
	row.Size = UDim2.new(1, 0, 0, ROWH)
	row.BackgroundTransparency = 1
	row.Text = ""
	row.AutoButtonColor = false

	local nm = Instance.new("TextLabel", row)
	nm.Size = UDim2.new(1, -58, 1, 0)
	nm.Position = UDim2.new(0, 2, 0, 0)
	nm.BackgroundTransparency = 1
	nm.Text = def.name .. "  " .. def.id
	nm.Font = Enum.Font.Gotham
	nm.TextSize = 13
	nm.TextColor3 = Color3.fromRGB(196, 204, 220)
	nm.TextXAlignment = Enum.TextXAlignment.Left

	local track = Instance.new("Frame", row)
	track.Size = UDim2.new(0, 40, 0, 20)
	track.AnchorPoint = Vector2.new(1, 0.5)
	track.Position = UDim2.new(1, 0, 0.5, 0)
	track.BackgroundColor3 = Color3.fromRGB(50, 55, 72)
	track.BorderSizePixel = 0
	Instance.new("UICorner", track).CornerRadius = UDim.new(0, 4)

	local knob = Instance.new("Frame", track)
	knob.Size = UDim2.new(0, 14, 0, 14)
	knob.Position = UDim2.new(0, 3, 0.5, -7)
	knob.BackgroundColor3 = Color3.fromRGB(148, 156, 175)
	knob.BorderSizePixel = 0
	Instance.new("UICorner", knob).CornerRadius = UDim.new(0, 4)

	local function paint(anim)
		local on = CFG.Sects[def.id] == true
		local ti = TweenInfo.new(anim and 0.22 or 0, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
		TWS:Create(knob, ti, {
			Position = on and UDim2.new(0, 23, 0.5, -7) or UDim2.new(0, 3, 0.5, -7),
			BackgroundColor3 = on and Color3.fromRGB(96, 232, 180) or Color3.fromRGB(148, 156, 175),
		}):Play()
		TWS:Create(track, ti, {
			BackgroundColor3 = on and Color3.fromRGB(28, 68, 58) or Color3.fromRGB(50, 55, 72),
		}):Play()
		TWS:Create(nm, ti, {
			TextColor3 = on and Color3.fromRGB(242, 248, 255) or Color3.fromRGB(150, 158, 176),
		}):Play()
	end
	sectPainters[#sectPainters + 1] = paint
	paint(false)

	row.MouseButton1Click:Connect(function()
		if os.clock() - justDragged < 0.25 then
			return
		end
		if CFG.SectMulti then
			CFG.Sects[def.id] = not (CFG.Sects[def.id] == true)
		elseif CFG.Sects[def.id] == true then
			CFG.Sects[def.id] = false
		else
			for k in pairs(CFG.Sects) do
				CFG.Sects[k] = false
			end
			CFG.Sects[def.id] = true
		end
		repaintSects()
	end)
end

-- 地狱兽选择行：点谁打谁，并把「选层方式」切到手动。单选，点一个顶掉其他。
local hellPainters = {}

local function repaintHell()
	for _, p in ipairs(hellPainters) do
		p(false)
	end
end

local function HellRow(page, def)
	local row = Instance.new("TextButton", page)
	row.Size = UDim2.new(1, 0, 0, ROWH)
	row.BackgroundTransparency = 1
	row.Text = ""
	row.AutoButtonColor = false

	local nm = Instance.new("TextLabel", row)
	nm.Size = UDim2.new(1, -58, 1, 0)
	nm.Position = UDim2.new(0, 2, 0, 0)
	nm.BackgroundTransparency = 1
	nm.Text = ("%d. %s"):format(def.rank, def.name)
	nm.Font = Enum.Font.Gotham
	nm.TextSize = 13
	nm.TextColor3 = Color3.fromRGB(196, 204, 220)
	nm.TextXAlignment = Enum.TextXAlignment.Left

	local track = Instance.new("Frame", row)
	track.Size = UDim2.new(0, 40, 0, 20)
	track.AnchorPoint = Vector2.new(1, 0.5)
	track.Position = UDim2.new(1, 0, 0.5, 0)
	track.BackgroundColor3 = Color3.fromRGB(50, 55, 72)
	track.BorderSizePixel = 0
	Instance.new("UICorner", track).CornerRadius = UDim.new(0, 4)

	local knob = Instance.new("Frame", track)
	knob.Size = UDim2.new(0, 14, 0, 14)
	knob.Position = UDim2.new(0, 3, 0.5, -7)
	knob.BackgroundColor3 = Color3.fromRGB(148, 156, 175)
	knob.BorderSizePixel = 0
	Instance.new("UICorner", knob).CornerRadius = UDim.new(0, 4)

	local function paint(anim)
		-- 手动模式下选中那一只才亮
		local on = (not CFG.HellAuto) and (tonumber(CFG.HellPick) == def.rank)
		local ti = TweenInfo.new(anim and 0.22 or 0, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
		TWS:Create(knob, ti, {
			Position = on and UDim2.new(0, 23, 0.5, -7) or UDim2.new(0, 3, 0.5, -7),
			BackgroundColor3 = on and Color3.fromRGB(96, 232, 180) or Color3.fromRGB(148, 156, 175),
		}):Play()
		TWS:Create(track, ti, {
			BackgroundColor3 = on and Color3.fromRGB(28, 68, 58) or Color3.fromRGB(50, 55, 72),
		}):Play()
		TWS:Create(nm, ti, {
			TextColor3 = on and Color3.fromRGB(242, 248, 255) or Color3.fromRGB(150, 158, 176),
		}):Play()
	end
	hellPainters[#hellPainters + 1] = paint
	paint(false)

	row.MouseButton1Click:Connect(function()
		if os.clock() - justDragged < 0.25 then
			return
		end
		CFG.HellAuto = false
		CFG.HellPick = def.rank
		hellRank = def.rank
		repaintHell()
		print(("[Tianjie] 地狱目标改为 %d.%s（手动）"):format(def.rank, def.name))
	end)
end

local function InputRow(page, label, get, set, width)
	local row = Instance.new("Frame", page)
	row.Size = UDim2.new(1, 0, 0, ROWH)
	row.BackgroundTransparency = 1

	local nm = Instance.new("TextLabel", row)
	nm.Size = UDim2.new(1, -(width + 14), 1, 0)
	nm.Position = UDim2.new(0, 2, 0, 0)
	nm.BackgroundTransparency = 1
	nm.Text = label
	nm.Font = Enum.Font.Gotham
	nm.TextSize = 13
	nm.TextColor3 = Color3.fromRGB(180, 188, 206)
	nm.TextXAlignment = Enum.TextXAlignment.Left

	local box = Instance.new("TextBox", row)
	box.Size = UDim2.new(0, width, 0, 22)
	box.AnchorPoint = Vector2.new(0.5, 0.5)
	box.Position = UDim2.new(1, -(width / 2), 0.5, 0)
	box.BackgroundColor3 = Color3.fromRGB(40, 45, 60)
	box.BorderSizePixel = 0
	box.Text = tostring(get())
	box.ClearTextOnFocus = false
	box.Font = Enum.Font.GothamBold
	box.TextSize = 11
	box.TextColor3 = Color3.fromRGB(226, 232, 245)
	Instance.new("UICorner", box).CornerRadius = UDim.new(0, 4)

	box.FocusLost:Connect(function()
		local n = tonumber(box.Text)
		if n and n >= 0 then
			set(math.floor(n))
		end
		box.Text = tostring(get())
	end)
	return box
end

local function InfoRow(page, color)
	local l = Instance.new("TextLabel", page)
	l.Size = UDim2.new(1, 0, 0, 18)
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.GothamBold
	l.TextSize = 11
	l.TextColor3 = color or Color3.fromRGB(140, 150, 175)
	l.TextXAlignment = Enum.TextXAlignment.Left
	return l
end

addTab("核心")
addTab("宗门")
addTab("灵根")
addTab("战斗")
addTab("地狱")
addTab("AFK")
layoutTabs()

local p1, p2, p3, p4, p5, p6 = newPage(), newPage(), newPage(), newPage(), newPage(), newPage()

Toggle(p1, "自动突破", "Breakthrough")
Toggle(p1, "最大精炼", "Refine")
Toggle(p1, "自动重生", "Ascend")
Toggle(p1, "打坐修炼", "Meditate")
Toggle(p1, "日常奖励", "Daily")
Toggle(p1, "吃所有秘籍", "Books")
Toggle(p1, "使用丹药", "Pill")
Toggle(p1, "买 Silk Casket", "Casket")
InputRow(p1, "重生间隔秒", function()
	return CFG.AscendEvery
end, function(v)
	CFG.AscendEvery = math.max(0.5, v)
end, 58)
InputRow(p1, "境界门槛(0=不限)", function()
	return CFG.AscendMinStage
end, function(v)
	CFG.AscendMinStage = v
end, 58)
local ascendTip = InfoRow(p1, Color3.fromRGB(110, 118, 138))
ascendTip.Text = "游戏只要第4境界 · 重生次数无上限"
InputRow(p1, "保留灵石", function()
	return CFG.Reserve
end, function(v)
	CFG.Reserve = v
end, 58)
ascendLbl = InfoRow(p1, Color3.fromRGB(150, 200, 255))
ascendLbl.Text = "重生 0 次"
CycleRow(p1, "退出并清理脚本", function()
	return "点我退出"
end, shutdown, 88)
local exitTip = InfoRow(p1, Color3.fromRGB(110, 118, 138))
exitTip.Text = "停所有循环 · 断连接 · 销毁界面"

Toggle(p2, "自动加入宗门", "JoinSect")
CycleRow(p2, "宗门模式", function()
	return CFG.SectMulti and "多选·轮流" or "单选"
end, function()
	CFG.SectMulti = not CFG.SectMulti
	if not CFG.SectMulti then
		-- 切回单选只留第一个，免得留下多个选中看不出哪个生效
		local picks = sectPicks()
		for k in pairs(CFG.Sects) do
			CFG.Sects[k] = false
		end
		if picks[1] then
			CFG.Sects[picks[1]] = true
		end
		repaintSects()
	end
end, 84)
InputRow(p2, "轮流分钟", function()
	return CFG.SectRotateMin
end, function(v)
	CFG.SectRotateMin = math.max(1, v)
end, 52)
local sectTip = InfoRow(p2, Color3.fromRGB(110, 118, 138))
sectTip.Text = "选中=要去的宗门 · 单选点一个顶掉其他"
for _, def in ipairs(SECTS) do
	SectRow(p2, def)
end

Toggle(p2, "打宗门长老", "Spar")
Toggle(p2, "自动打长老(游戏)", "AutoSpar")
Toggle(p2, "工会任务", "Mission")
Toggle(p2, "自动晋升", "Promote")
Toggle(p2, "自动学手册", "Manual")
Toggle(p2, "宗门修炼室", "Room")
CycleRow(p2, "目标职位", function()
	return RANKS[CFG.AscendRank] or tostring(CFG.AscendRank)
end, function()
	CFG.AscendRank = (CFG.AscendRank % #RANKS) + 1
end, 76)

Toggle(p3, "刷混沌灵根", "Roll")
Toggle(p3, "只存混沌根", "OnlyChaos")
Toggle(p3, "游戏自动灵根", "AutoRoll")
CycleRow(p3, "目标根品质", function()
	return CFG.RollTarget
end, function()
	local i = table.find(ROLL_TARGETS, CFG.RollTarget) or 1
	CFG.RollTarget = ROLL_TARGETS[(i % #ROLL_TARGETS) + 1]
end, 66)
Toggle(p3, "自动神化(游戏)", "AutoDivine")
Toggle(p3, "血脉抽取", "Bloodline")
Toggle(p3, "神体抽取", "Divine")
Toggle(p3, "抽取天赋", "Talent")
rollLbl = InfoRow(p3, Color3.fromRGB(255, 210, 120))
rollLbl.Text = "灵石 —"

Toggle(p4, "自动 Boss", "Boss")
CycleRow(p4, "Boss 难度", function()
	return CFG.Difficulty
end, function()
	local i = table.find(DIFFS, CFG.Difficulty) or 1
	CFG.Difficulty = DIFFS[(i % #DIFFS) + 1]
end, 62)
Toggle(p4, "自动探索副本", "Explore")
CycleRow(p4, "探索关卡", function()
	return CFG.ExploreStage
end, function()
	local i = table.find(STAGES, CFG.ExploreStage) or 1
	CFG.ExploreStage = STAGES[(i % #STAGES) + 1]
end, 78)
InputRow(p4, "攻击间隔秒", function()
	return CFG.TapRate
end, function(v)
	-- 游戏自己的上限是 TAP_COOLDOWN = 0.09，再低会被丢
	CFG.TapRate = math.max(0.09, v)
end, 58)
local tapTip = InfoRow(p4, Color3.fromRGB(110, 118, 138))
tapTip.Text = "0.09 是游戏上限(约11次/秒) · 越高越慢"
exploreLbl = InfoRow(p4, Color3.fromRGB(150, 200, 255))
exploreLbl.Text = "探索次数 —"

Toggle(p5, "自动地狱门", "Hell")
CycleRow(p5, "地狱难度", function()
	return CFG.HellDiff
end, function()
	local i = table.find(HELL_DIFFS, CFG.HellDiff) or 1
	CFG.HellDiff = HELL_DIFFS[(i % #HELL_DIFFS) + 1]
end, 78)
CycleRow(p5, "选层方式", function()
	return CFG.HellAuto and "自动·打最深" or "手动·指定"
end, function()
	CFG.HellAuto = not CFG.HellAuto
	if CFG.HellAuto then
		hellRank = nil -- 回自动就重新从最深层算起
	end
	repaintHell()
end, 100)
Toggle(p5, "只在 5 倍期打", "HellFreshOnly")
InputRow(p5, "开战间隔秒", function()
	return CFG.HellAgain
end, function(v)
	CFG.HellAgain = math.max(2, v)
end, 52)
hellLbl = InfoRow(p5, Color3.fromRGB(232, 150, 90))
hellLbl.Text = "地狱 0 胜 · 待机"
hellTipLbl = InfoRow(p5, Color3.fromRGB(110, 118, 138))
hellTipLbl.Text = "点下面名字=指定打它 · 自动模式会打赢往深爬、打输降层"
for _, def in ipairs(HELL_BEASTS) do
	HellRow(p5, def)
end
Toggle(p5, "自动买地狱精华", "HellMarket")
CycleRow(p5, "购买目标", function()
	return CFG.HellBuy
end, function()
	local i = table.find(HELL_BUYS, CFG.HellBuy) or 1
	CFG.HellBuy = HELL_BUYS[(i % #HELL_BUYS) + 1]
end, 88)
InputRow(p5, "精华保留量", function()
	return CFG.HellReserve
end, function(v)
	CFG.HellReserve = v
end, 58)
CycleRow(p5, "重置地狱冷却", function()
	return "点我清空"
end, function()
	hellRetryAt = {}
	hellRank = nil
	print("[Tianjie] 地狱冷却已清空，重新从最深层开始")
end, 92)

Toggle(p6, "Anti-AFK 保活", "AntiAFK")
Toggle(p6, "自动领挂机奖励", "AutoClaimAFK")
InputRow(p6, "心跳间隔秒", function()
	return CFG.Heartbeat
end, function(v)
	CFG.Heartbeat = math.max(5, v)
end, 52)
InputRow(p6, "挂机多久才领", function()
	return CFG.AFKClaimMin
end, function(v)
	CFG.AFKClaimMin = math.max(30, v)
end, 52)
afkLbl = InfoRow(p6, Color3.fromRGB(130, 220, 190))
afkLbl.Text = "未挂机"
local hbTip = InfoRow(p6, Color3.fromRGB(110, 118, 138))
hbTip.Text = "保活方式: 检测中"

statLbl = Instance.new("TextLabel", panel)
statLbl.Size = UDim2.new(1, -20, 0, 16)
statLbl.Position = UDim2.new(0, 10, 1, -18)
statLbl.BackgroundTransparency = 1
statLbl.Font = Enum.Font.GothamBold
statLbl.TextSize = 10
statLbl.TextColor3 = Color3.fromRGB(120, 130, 155)
statLbl.TextXAlignment = Enum.TextXAlignment.Left

moveBtn.MouseButton1Click:Connect(function()
	if os.clock() - justDragged < 0.25 then
		return
	end
	moveMode = not moveMode
	moveBtn.TextColor3 = moveMode and Color3.fromRGB(96, 232, 180) or Color3.fromRGB(198, 206, 224)
	moveBtn.BackgroundColor3 = moveMode and Color3.fromRGB(28, 68, 58) or Color3.fromRGB(38, 43, 58)
	for _, pg in ipairs(pages) do
		pg.ScrollingEnabled = not moveMode
	end
end)

local collapsed = false
local fullH = BAR + TABH + 200

local function clampPos()
	local p = panel.AbsolutePosition
	local sz = panel.AbsoluteSize
	local vp = cam.ViewportSize
	panel.Position = UDim2.new(
		0,
		math.clamp(p.X, 0, math.max(vp.X - sz.X, 0)),
		0,
		math.clamp(p.Y, 0, math.max(vp.Y - sz.Y, 0))
	)
end

function relayout()
	MAXBODY = math.floor(cam.ViewportSize.Y * 0.6)
	local h = 200
	for _, pg in ipairs(pages) do
		if pg.Visible then
			h = math.min(pg:FindFirstChildOfClass("UIListLayout").AbsoluteContentSize.Y + 46, MAXBODY)
		end
	end
	h = math.max(h, 90)
	fullH = BAR + TABH + h
	bodyHost.Size = UDim2.new(1, 0, 0, h)
	panel.Size = UDim2.new(0, WIDE, 0, collapsed and BAR or fullH)
	tabBar.Visible = not collapsed
	statLbl.Visible = not collapsed
end

task.defer(function()
	task.wait()
	relayout()
	panel.Position = UDim2.new(0, panel.Position.X.Offset, 0.5, -fullH / 2)
end)

task.spawn(function()
	while alive() do
		if hbTip then
			hbTip.Text = ("保活: %s · %ds 前"):format(hbMode, hbAt > 0 and math.floor(os.clock() - hbAt) or 0)
		end
		task.wait(1)
	end
end)

track(cam:GetPropertyChangedSignal("ViewportSize"):Connect(function()
	task.wait(0.25)
	SC = uiScale()
	WIDE = math.floor(268 * SC)
	BAR = math.floor(40 * math.max(SC, 0.92))
	TABH = math.floor(30 * math.max(SC, 0.92))
	ROWH = touch and 34 or 30
	bar.Size = UDim2.new(1, 0, 0, BAR)
	tabBar.Size = UDim2.new(1, 0, 0, TABH)
	tabBar.Position = UDim2.new(0, 0, 0, BAR)
	bodyHost.Position = UDim2.new(0, 0, 0, BAR + TABH)
	for _, pg in ipairs(pages) do
		for _, c in ipairs(pg:GetChildren()) do
			if c:IsA("TextButton") or c:IsA("Frame") then
				c.Size = UDim2.new(1, 0, 0, ROWH)
			end
		end
	end
	relayout()
	clampPos()
end))

local function setCollapsed(v)
	collapsed = v
	mini.Text = collapsed and "+" or "—"
	tabBar.Visible = not collapsed
	statLbl.Visible = not collapsed
	TWS:Create(panel, TweenInfo.new(0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
		Size = UDim2.new(0, WIDE, 0, collapsed and BAR or fullH),
	}):Play()
end

mini.MouseButton1Click:Connect(function()
	if os.clock() - justDragged < 0.25 then
		return
	end
	setCollapsed(not collapsed)
end)

local dragStart, startPos, dragActive, dragging
local function endDrag()
	if dragging then
		justDragged = os.clock()
	end
	dragActive = false
	dragging = false
end

panel.InputBegan:Connect(function(i)
	if i.UserInputType ~= Enum.UserInputType.MouseButton1 and i.UserInputType ~= Enum.UserInputType.Touch then
		return
	end
	if not moveMode then
		local pg = pages[activeTab]
		local bp = pg and pg.AbsolutePosition
		local bs = pg and pg.AbsoluteSize
		if bp and i.Position.X >= bp.X and i.Position.X <= bp.X + bs.X and i.Position.Y >= bp.Y and i.Position.Y <= bp.Y + bs.Y then
			return
		end
	end
	dragStart = i.Position
	startPos = panel.Position
	dragActive = true
	dragging = false
end)

panel.InputEnded:Connect(endDrag)
track(UIS.InputEnded:Connect(function(i)
	if i.UserInputType == Enum.UserInputType.Touch then
		endDrag()
	end
end))

local function onDrag(i)
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
end

track(UIS.InputChanged:Connect(onDrag))
track(UIS.TouchMoved:Connect(onDrag))

task.spawn(function()
	while alive() do
		TWS:Create(dot, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {
			BackgroundColor3 = anyOn() and Color3.fromRGB(96, 232, 180) or Color3.fromRGB(120, 130, 150),
		}):Play()
		task.wait(1.5)
	end
end)

getgenv().TianjieCfg = CFG
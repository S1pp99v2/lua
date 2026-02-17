-- ===================== 【Roblox 一键加载总入口】 =====================
-- 文件名：roblox_main_loader.lua
-- 适配你的仓库：https://github.com/S1pp99v2/lua
local REPO_BASE_URL = "https://raw.githubusercontent.com/S1pp99v2/lua/main/"

-- 模块加载顺序（速度→飞行→UI，必须按这个顺序）
local modules = {
    "roblox_speed_module.lua",
    "roblox_fly_module.lua",
    "roblox_ui_module.lua"
}

-- 安全加载远程模块
local function loadRemoteModule(moduleName)
    local fullUrl = REPO_BASE_URL .. moduleName
    print("[📥] 开始加载模块：" .. moduleName .. " (" .. fullUrl .. ")")
    
    -- 尝试获取模块代码
    local success, moduleCode = pcall(function()
        return game:HttpGet(fullUrl, true)
    end)
    
    if not success then
        warn("[❌] 加载模块失败：" .. moduleName .. "，错误：" .. moduleCode)
        return false
    end
    
    -- 执行模块代码
    local execSuccess, execErr = pcall(function()
        loadstring(moduleCode)()
    end)
    
    if not execSuccess then
        warn("[❌] 执行模块失败：" .. moduleName .. "，错误：" .. execErr)
        return false
    end
    
    print("[✅] 模块加载成功：" .. moduleName)
    return true
end

-- 批量加载所有模块
local function loadAllModules()
    print("====================================")
    print("🔧 开始一键加载Roblox模块（S1pp99v2/lua）")
    print("====================================")
    
    for _, moduleName in ipairs(modules) do
        if not loadRemoteModule(moduleName) then
            warn("[❌] 核心模块加载失败，停止加载")
            return
        end
        task.wait(0.5) -- 给模块初始化留时间
    end
    
    print("====================================")
    print("🎉 所有模块加载完成！")
    print("🔧 操作说明：")
    print("   • G键：打开/关闭UI菜单")
    print("   • F键：切换飞行")
    print("   • +/-键：调节地面速度")
    print("====================================")
end

-- 启动加载
loadAllModules()

-- ===================== 【Roblox 一键加载总入口】 =====================
-- 文件名：roblox_main_loader.lua
-- 功能：一键加载飞行、速度、UI模块，只需这一个远程链接
-- 替换成你的GitHub仓库地址！
local REPO_BASE_URL = "https://raw.githubusercontent.com/你的用户名/你的仓库名/main/"

-- 模块加载顺序（必须按这个顺序）
local modules = {
    "roblox_speed_module.lua",
    "roblox_fly_module.lua",
    "roblox_ui_module.lua"
}

-- 安全加载远程模块
local function loadRemoteModule(moduleName)
    local fullUrl = REPO_BASE_URL .. moduleName
    print("[📥] 加载模块：" .. moduleName)
    
    local success, moduleCode = pcall(function()
        return game:HttpGet(fullUrl, true)
    end)
    
    if not success then
        warn("[❌] 加载失败：" .. moduleName .. " | 错误：" .. moduleCode)
        return false
    end
    
    local execSuccess, execErr = pcall(function()
        loadstring(moduleCode)()
    end)
    
    if not execSuccess then
        warn("[❌] 执行失败：" .. moduleName .. " | 错误：" .. execErr)
        return false
    end
    
    print("[✅] 加载成功：" .. moduleName)
    return true
end

-- 批量加载
local function loadAllModules()
    print("====================================")
    print("🔧 开始一键加载Roblox模块")
    print("====================================")
    
    for _, moduleName in ipairs(modules) do
        if not loadRemoteModule(moduleName) then
            warn("[❌] 核心模块加载失败，终止")
            return
        end
        task.wait(0.5)
    end
    
    print("====================================")
    print("🎉 所有模块加载完成！")
    print("🔧 快捷键：G-菜单 | F-飞行 | +/--调速")
    print("====================================")
end

-- 启动加载
loadAllModules()

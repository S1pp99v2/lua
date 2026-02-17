-- ===================== 【Roblox 一键加载总入口】 =====================
-- 文件名：roblox_main_loader.lua
-- 适配你的仓库：https://github.com/S1pp99v2/lua
local REPO_BASE_URL = "https://raw.githubusercontent.com/S1pp99v2/lua/main/"

-- 先只加载飞行和UI，速度模块等角色加载后手动加载
local modules = {
    "roblox_fly_module.lua",
    "roblox_ui_module.lua"
}

-- 安全加载远程模块
local function loadRemoteModule(moduleName)
    local fullUrl = REPO_BASE_URL .. moduleName
    print("[📥] 开始加载模块：" .. moduleName .. " (" .. fullUrl .. ")")
    
    local success, moduleCode = pcall(function()
        return game:HttpGet(fullUrl, true)
    end)
    
    if not success then
        warn("[❌] 加载模块失败：" .. moduleName .. "，错误：" .. moduleCode)
        return false
    end
    
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

-- 批量加载
local function loadAllModules()
    print("====================================")
    print("🔧 开始一键加载Roblox模块（S1pp99v2/lua）")
    print("====================================")
    
    for _, moduleName in ipairs(modules) do
        if not loadRemoteModule(moduleName) then
            warn("[❌] 核心模块加载失败，停止加载")
            return
        end
        task.wait(0.5)
    end
    
    print("====================================")
    print("🎉 飞行+UI模块加载完成！")
    print("🔧 操作说明：")
    print("   • G键：打开/关闭UI菜单")
    print("   • F键：切换飞行")
    print("   • 请等角色完全加载后，手动加载速度模块")
    print("====================================")
end

-- 启动加载
loadAllModules()

-- ===================== 【Roblox 独立速度模块】 =====================
-- 文件名：roblox_speed_module.lua
-- 功能：纯速度调节，+/-键调速，无UI，暴露全局函数供UI调用
-- 快捷键：+键 - 加速10 | -键 - 减速10
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

-- 全局变量（暴露给UI/飞行模块）
getgenv().SpeedModule = {
    CurrentWalkSpeed = 16,
    Character = nil,
    Humanoid = nil
}
local SM = getgenv().SpeedModule

-- 安全获取角色和人形对象（修复版：等待角色加载）
local function getCharacter()
    local success, result = pcall(function()
        -- 先等待角色存在
        SM.Character = Players.LocalPlayer.Character or Players.LocalPlayer.CharacterAdded:Wait()
        -- 再等待Humanoid加载
        SM.Humanoid = SM.Character:WaitForChild("Humanoid", 10)
        return true
    end)
    if not success then
        warn("[速度模块] 获取角色失败：" .. result)
        return false
    end
    return true
end

-- 设置地面速度（暴露函数）
function SM:setWalkSpeed(speed)
    local numSpeed = tonumber(speed) or 16
    self.CurrentWalkSpeed = math.clamp(numSpeed, 0, 500) -- 限制0-500，防止数值异常
    
    -- 先获取角色，再设置速度
    if getCharacter() then
        -- 只有不在飞行时才设置速度
        local flyModule = getgenv().FlyModule
        if not (flyModule and flyModule.IsFlying) then
            self.Humanoid.WalkSpeed = self.CurrentWalkSpeed
            print("[⚡ 速度模块] 地面速度已设置为：" .. self.CurrentWalkSpeed)
        end
    end
end

-- 初始化速度模块
local function init()
    -- 初始化默认速度（先等待角色加载）
    getCharacter()
    if self.Humanoid then
        self.Humanoid.WalkSpeed = SM.CurrentWalkSpeed
    end
    
    -- 绑定+/-键调速
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if input.KeyCode == Enum.KeyCode.Plus or input.KeyCode == Enum.KeyCode.Equals then
            SM:setWalkSpeed(SM.CurrentWalkSpeed + 10)
        elseif input.KeyCode == Enum.KeyCode.Minus then
            SM:setWalkSpeed(SM.CurrentWalkSpeed - 10)
        end
    end)
    
    -- 角色重生重置速度
    Players.LocalPlayer.CharacterAdded:Connect(function()
        task.wait(0.5)
        SM:setWalkSpeed(SM.CurrentWalkSpeed)
    end)
    
    print("[✅ 速度模块] 加载成功 | +/-键调节速度（每次±10）")
end

-- 启动模块
init()

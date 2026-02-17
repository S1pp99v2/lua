-- ===================== 【Roblox 极简速度模块】 =====================
-- 文件名：roblox_speed_module.lua
-- 功能：只维护速度值，角色重生时自动应用，彻底避免加载报错
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

-- 全局变量（只存速度值，不存角色对象）
getgenv().SpeedModule = {
    CurrentWalkSpeed = 16
}
local SM = getgenv().SpeedModule

-- 应用速度到当前角色（内部函数，失败不报错）
local function applySpeedToCurrentCharacter()
    local success, err = pcall(function()
        local player = Players.LocalPlayer
        if not player then return end
        local char = player.Character
        if not char then return end
        local humanoid = char:FindFirstChild("Humanoid")
        if humanoid then
            -- 只有不在飞行时才应用速度
            local flyModule = getgenv().FlyModule
            if not (flyModule and flyModule.IsFlying) then
                humanoid.WalkSpeed = SM.CurrentWalkSpeed
            end
        end
    end)
    if not success then
        warn("[速度模块] 应用速度失败：" .. tostring(err))
    end
end

-- 绑定+/-键调速（只更新值，不主动应用）
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.Plus or input.KeyCode == Enum.KeyCode.Equals then
        SM.CurrentWalkSpeed = math.clamp(SM.CurrentWalkSpeed + 10, 0, 500)
        print("[⚡ 速度模块] 速度值更新为：" .. SM.CurrentWalkSpeed)
        applySpeedToCurrentCharacter() -- 尝试应用，失败也不影响模块运行
    elseif input.KeyCode == Enum.KeyCode.Minus then
        SM.CurrentWalkSpeed = math.clamp(SM.CurrentWalkSpeed - 10, 0, 500)
        print("[⚡ 速度模块] 速度值更新为：" .. SM.CurrentWalkSpeed)
        applySpeedToCurrentCharacter() -- 尝试应用，失败也不影响模块运行
    end
end)

-- 角色重生时自动应用速度（核心逻辑）
Players.LocalPlayer.CharacterAdded:Connect(function()
    -- 延迟1秒，确保角色完全加载
    task.wait(1)
    applySpeedToCurrentCharacter()
    print("[⚡ 速度模块] 角色重生，已自动应用速度：" .. SM.CurrentWalkSpeed)
end)

-- 模块加载完成
print("[✅ 速度模块] 加载成功 | +/-键调节速度（每次±10），角色重生时自动生效")

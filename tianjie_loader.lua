-- 天界 AUTO 加载器：多镜像 + 本地缓存 + 按提交号绕 CDN 缓存。
-- 用法：loadstring(game:HttpGet('https://<你的地址>/tianjie_loader.lua'))()

local REPO = "S1pp99v2/lua"
local FILE = "tianjie.lua"
local CACHE_FILE = "tianjie.cache.lua"

-- 下载内容校验：必须同时出现，且不能太短，挡住 404 页面和半截响应。
-- 特征串拆开拼接，避免加载器自己匹配到自己（配合 MIN_LEN 双保险）。
local MARKERS = { "Tianjie" .. "Cfg", "Cult" .. "RealmIndex" }
local MIN_LEN = 20000

local function grab(name)
	local found
	pcall(function()
		found = ({
			getgenv = getgenv,
			loadstring = loadstring,
			load = load,
			writefile = writefile,
			readfile = readfile,
			isfile = isfile,
			request = request,
			http_request = http_request,
		})[name]
	end)
	if type(found) == "function" then
		return found
	end
	pcall(function()
		found = _G[name]
	end)
	if type(found) == "function" then
		return found
	end
	pcall(function()
		local genv = getgenv
		if type(genv) == "function" then
			found = genv()[name]
		end
	end)
	if type(found) == "function" then
		return found
	end
	return nil
end

local getgenvFn = grab("getgenv")
local writefileFn = grab("writefile")
local readfileFn = grab("readfile")
local isfileFn = grab("isfile")
-- 有的执行器只留 load，不留 loadstring
local compileFn = grab("loadstring") or grab("load")

local env = _G
if type(getgenvFn) == "function" then
	pcall(function()
		local g = getgenvFn()
		if type(g) == "table" then
			env = g
		end
	end)
end

local function httpGet(url)
	local body
	pcall(function()
		body = game:HttpGet(url)
	end)
	if type(body) == "string" and body ~= "" then
		return body
	end
	local req = grab("request") or grab("http_request")
	if type(req) ~= "function" then
		pcall(function()
			req = syn and syn.request
		end)
	end
	if type(req) == "function" then
		local ok, res = pcall(req, { Url = url, Method = "GET" })
		if ok and type(res) == "table" and type(res.Body) == "string" then
			return res.Body
		end
	end
	return nil
end

local function latestSha()
	local body = httpGet("https://api.github.com/repos/" .. REPO .. "/commits/main")
	if type(body) ~= "string" then
		return nil
	end
	return string.match(body, '"sha"%s*:%s*"([a-f0-9]+)"')
end

local function urlList()
	local stamp = tostring(os.time())
	local sha = latestSha()
	local list = {}
	-- m1/m2 是同一份内容的两套主机名，国内 cdn.jsdelivr.net 常被挡而 fastly 还能通，
	-- 所以 fastly 放前面。钉提交号是为了绕开 jsDelivr 对 @main 的缓存。
	local hosts = { "fastly.jsdelivr.net", "cdn.jsdelivr.net" }
	if type(sha) == "string" and #sha >= 7 then
		for _, h in ipairs(hosts) do
			list[#list + 1] = "https://" .. h .. "/gh/" .. REPO .. "@" .. sha .. "/" .. FILE
		end
		print("[Tianjie] commit " .. string.sub(sha, 1, 7))
	end
	for _, h in ipairs(hosts) do
		list[#list + 1] = "https://" .. h .. "/gh/" .. REPO .. "@main/" .. FILE .. "?t=" .. stamp
	end
	list[#list + 1] = "https://raw.githubusercontent.com/" .. REPO .. "/main/" .. FILE .. "?t=" .. stamp
	list[#list + 1] = "https://github.com/" .. REPO .. "/raw/main/" .. FILE .. "?t=" .. stamp
	return list
end

local function goodSource(src)
	if type(src) ~= "string" or #src < MIN_LEN then
		return false
	end
	for _, m in ipairs(MARKERS) do
		if not string.find(src, m, 1, true) then
			return false
		end
	end
	return true
end

local function runSource(src, from)
	if type(compileFn) ~= "function" then
		warn("[Tianjie] 这个执行器没有 loadstring/load")
		return
	end
	local fn, err = compileFn(src)
	if type(fn) ~= "function" then
		warn("[Tianjie] 编译失败: " .. tostring(err))
		return
	end
	print("[Tianjie] load from " .. from)
	fn()
end

local urls = urlList()
env._TianjieScriptUrls = urls
env._TianjieScriptUrl = urls[1]

local src = nil
for _, url in ipairs(urls) do
	src = httpGet(url)
	if goodSource(src) then
		env._TianjieScriptUrl = url
		print("[Tianjie] remote " .. url)
		break
	end
	src = nil
end

if goodSource(src) then
	if type(writefileFn) == "function" then
		pcall(writefileFn, CACHE_FILE, src)
	end
	runSource(src, "remote")
	return
end

print("[Tianjie] 远程失败，尝试本地缓存")
if type(isfileFn) == "function" and type(readfileFn) == "function" then
	local ok, cached = pcall(function()
		if isfileFn(CACHE_FILE) then
			return readfileFn(CACHE_FILE)
		end
		return nil
	end)
	if ok and goodSource(cached) then
		runSource(cached, "cache")
		return
	end
end

warn("[Tianjie] 远程和缓存都不可用")

--> Locates the reference Studio install the differential checks compare against, and the pristine copies the
--> Python tool left beside every file it themed. Returns nil when no install is present so a check can skip.

local locate = require("../../src/studio/locate")

local liveInstall = {}

function liveInstall.find(): locate.Location?
	local location = locate.locate({})

	return location
end

function liveInstall.pristineExe(location: locate.Location): string
	return location.exe .. ".plugverify-bak"
end

function liveInstall.pristinePlugin(location: locate.Location, name: string): string
	return `{location.pluginDir}/{name}.rbxm.orig-bak`
end

function liveInstall.livePlugin(location: locate.Location, name: string): string
	return `{location.pluginDir}/{name}.rbxm`
end

function liveInstall.skip(reason: string)
	print(`skip: {reason}`)
end

return liveInstall

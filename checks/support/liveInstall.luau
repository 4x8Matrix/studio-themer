--> Locates the reference Studio install the differential checks compare against, and the pristine copies the
--> Python tool left beside every file it themed. Decodes the Python-written plugin frames with the zstd CLI because
--> they carry no content size, which zune's decoder needs. Returns nil when no install is present so a check can skip.

local StdPolyfills = require("../../luau_packages/std_polyfills")

local locate = require("../../src/studio/locate")
local rbxm = require("../../src/rbxm/rbxm")

local TEMP_DIR = ".harness/tmp"

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

function liveInstall.sourcePayload(model: rbxm.Model): string?
	local _, raw = rbxm.findSourceChunk(model)

	if raw then
		return raw
	end

	local largestIndex
	local largestSize = -1

	for index, chunk in model.chunks do
		if string.gsub(chunk.name, "%z+$", "") == "PROP" and chunk.uncompressed > largestSize then
			largestSize = chunk.uncompressed
			largestIndex = index
		end
	end

	if not largestIndex then
		return
	end

	StdPolyfills.fileSystem.writeDir(TEMP_DIR)

	local framePath = `{TEMP_DIR}/frame-{StdPolyfills.process.getEnv().USER or "check"}.zst`
	StdPolyfills.fileSystem.writeFile(framePath, model.chunks[largestIndex].payload)

	local result = zune.process.run("zstd", { "-d", "-c", "-q", framePath }, {}, true)
	StdPolyfills.fileSystem.removeFile(framePath)

	if not result.ok or not result.stdout then
		return
	end

	return buffer.tostring(result.stdout :: buffer)
end

function liveInstall.skip(reason: string)
	print(`skip: {reason}`)
end

return liveInstall

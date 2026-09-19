--> What was last applied, and to which Studio version, so status can say when an update has wiped the patches.

local StdPolyfills = require("../../luau_packages/std_polyfills")

local STATE_SUBPATH = "/.config/studio-themer/state.json"

local state = {}

function state.path(): string
	return (StdPolyfills.process.getEnv().HOME or ".") .. STATE_SUBPATH
end

function state.read(): State?
	local ok, decoded = pcall(function(): State
		return StdPolyfills.serde.decode("json", StdPolyfills.fileSystem.readFile(state.path()))
	end)

	return if ok then decoded else nil
end

function state.write(value: State)
	local path = state.path()
	local directory = string.match(path, "^(.*)/[^/]+$")

	if directory then
		StdPolyfills.fileSystem.writeDir(directory)
	end

	StdPolyfills.fileSystem.writeFile(path, StdPolyfills.serde.encode("json", value, true))
end

function state.clear()
	local path = state.path()

	if StdPolyfills.fileSystem.isFile(path) then
		StdPolyfills.fileSystem.removeFile(path)
	end
end

export type State = {
	version: string,
	spec: string,
	mode: string,
	appliedAt: number,
}

return state

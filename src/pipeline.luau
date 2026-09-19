--> The orchestrator: apply runs every layer in order and idempotently, status reads each layer's on-disk state,
--> restore puts stock back. The exe is read once and written once. Nothing here prints; progress goes to the
--> caller's report callback so the CLI and the wizard render it their own way.

local StdPolyfills = require("../luau_packages/std_polyfills")

local assets = require("./assets")
local plugins = require("./layers/plugins")
local qtTheme = require("./layers/qtTheme")
local tokens = require("./layers/tokens")
local qtRedirect = require("./patches/qtRedirect")
local verifyBypass = require("./patches/verifyBypass")
local backup = require("./studio/backup")
local locate = require("./studio/locate")
local state = require("./studio/state")
local mapper = require("./theme/mapper")
local mode = require("./theme/mode")

local STEP_COUNT = 5
local PLUGIN_PROGRESS_START = 0.45
local PLUGIN_PROGRESS_END = 0.98

local pipeline = {}

local function readThemesFile(location: locate.Location, name: string): string?
	local path = `{location.themesDir}/{name}`

	if not StdPolyfills.fileSystem.isFile(path) then
		return
	end

	return StdPolyfills.fileSystem.readFile(path)
end

function pipeline.apply(spec: string, location: locate.Location, options: ApplyOptions): (ApplyReport?, string?)
	local ok, themeMapper = pcall(mapper.makeMapper, spec)

	if not ok then
		return nil, tostring(themeMapper)
	end

	local report = options.report
	local dryRun = options.dryRun
	local slots: mode.Mode = options.mode

	report({ index = 1, total = STEP_COUNT, name = "bypass", detail = "locating plugin verify gates", progress = 0.02 })

	local exe = StdPolyfills.fileSystem.readFile(location.exe)
	local bypassed, bypassError = verifyBypass.apply(exe)

	if not bypassed then
		return nil, `bypass: {bypassError}`
	end

	report({
		index = 1,
		total = STEP_COUNT,
		name = "bypass",
		detail = `{#bypassed.gates} gates, {bypassed.alreadyPatched} already patched, {bypassed.patched} to patch`,
		progress = 0.12,
	})
	report({ index = 2, total = STEP_COUNT, name = "redirect", detail = "locating Qt theme paths", progress = 0.14 })

	local redirected, redirectError = qtRedirect.apply(bypassed.data)

	if not redirected then
		return nil, `redirect: {redirectError}`
	end

	local exeChanged = bypassed.patched + redirected.patched > 0

	if exeChanged and not dryRun then
		backup.ensure(location.exe, backup.LEGACY_EXE)
		StdPolyfills.fileSystem.writeFile(location.exe, redirected.data)
	end

	report({
		index = 2,
		total = STEP_COUNT,
		name = "redirect",
		detail = `{redirected.patched} paths to redirect{if exeChanged and not dryRun then ", exe written" else ""}`,
		progress = 0.24,
	})
	report({ index = 3, total = STEP_COUNT, name = "qt-theme", detail = "building Foundation themes", progress = 0.26 })

	local baseDark = assets.read(qtTheme.FILE_NAMES.dark)
	local baseLight = assets.read(qtTheme.FILE_NAMES.light)
	local built = qtTheme.build(spec, baseDark, baseLight, themeMapper, slots)
	local qtWritten = 0
	local qtStocked = 0

	for slot, fileName in qtTheme.FILE_NAMES do
		local path = `{location.themesDir}/{fileName}`
		local themed = built[slot]

		if themed then
			qtWritten += 1

			if not dryRun then
				StdPolyfills.fileSystem.writeDir(location.themesDir)
				StdPolyfills.fileSystem.writeFile(path, themed)
			end
		elseif not StdPolyfills.fileSystem.isFile(path) then
			qtStocked += 1

			if not dryRun then
				StdPolyfills.fileSystem.writeDir(location.themesDir)
				StdPolyfills.fileSystem.writeFile(path, if slot == "dark" then baseDark else baseLight)
			end
		end
	end

	report({
		index = 3,
		total = STEP_COUNT,
		name = "qt-theme",
		detail = `{qtWritten} themed{if qtStocked > 0 then `, {qtStocked} stock` else ""} -> {location.themesDir}`,
		progress = 0.34,
	})
	report({ index = 4, total = STEP_COUNT, name = "tokens", detail = "rewriting Foundation palettes", progress = 0.36 })

	local tokenReport = tokens.apply(location.versionDir, spec, themeMapper, slots, dryRun)

	report({
		index = 4,
		total = STEP_COUNT,
		name = "tokens",
		detail = `{tokenReport.literals} literals across {tokenReport.files} files`,
		progress = PLUGIN_PROGRESS_START,
	})

	local pluginNames = plugins.list(location.pluginDir)
	local pluginIndex = 0
	local pluginReport = plugins.apply(location.pluginDir, themeMapper, dryRun, function(name: string)
		pluginIndex += 1
		report({
			index = 5,
			total = STEP_COUNT,
			name = "plugins",
			detail = `{name} ({pluginIndex}/{#pluginNames})`,
			progress = PLUGIN_PROGRESS_START
				+ (PLUGIN_PROGRESS_END - PLUGIN_PROGRESS_START) * (pluginIndex - 1) / math.max(1, #pluginNames),
		})
	end)

	report({
		index = 5,
		total = STEP_COUNT,
		name = "plugins",
		detail = `{pluginReport.themed} themed, {pluginReport.skipped} skipped, {pluginReport.restored} restored to stock`,
		progress = PLUGIN_PROGRESS_END,
	})

	if not dryRun then
		state.write({ version = location.version, spec = spec, mode = slots, appliedAt = os.time() })
	end

	report({ index = STEP_COUNT, total = STEP_COUNT, name = "done", detail = spec, progress = 1 })

	return {
		spec = spec,
		mode = slots,
		version = location.version,
		dryRun = dryRun,
		exe = {
			bypassPatched = bypassed.patched,
			bypassAlreadyPatched = bypassed.alreadyPatched,
			redirectPatched = redirected.patched,
			written = exeChanged and not dryRun,
		},
		tokens = tokenReport,
		plugins = pluginReport,
	}
end

function pipeline.status(location: locate.Location): StatusReport
	local exe = StdPolyfills.fileSystem.readFile(location.exe)
	local bypass, bypassError = verifyBypass.check(exe)
	local redirect = qtRedirect.check(exe)
	local lastApplied = state.read()
	local darkTheme = readThemesFile(location, qtTheme.FILE_NAMES.dark)
	local lightTheme = readThemesFile(location, qtTheme.FILE_NAMES.light)
	local tokensPristine, tokensTotal = tokens.countPristine(location.versionDir)
	local pluginsPristine, pluginsTotal = plugins.countPristine(location.pluginDir)

	return {
		version = location.version,
		lastApplied = lastApplied,
		updatedSinceApply = if lastApplied then lastApplied.version ~= location.version else false,
		bypassGates = if bypass then #bypass.gates else 0,
		bypassPatched = if bypass then bypass.patched else 0,
		bypassError = bypassError,
		redirectStock = #redirect.stock,
		redirectRedirected = #redirect.redirected,
		qtDarkSpec = if darkTheme then qtTheme.readSpec(darkTheme) else nil,
		qtLightSpec = if lightTheme then qtTheme.readSpec(lightTheme) else nil,
		qtPresent = if darkTheme and lightTheme then true else false,
		tokensPristine = tokensPristine,
		tokensTotal = tokensTotal,
		pluginsPristine = pluginsPristine,
		pluginsTotal = pluginsTotal,
	}
end

function pipeline.restore(location: locate.Location): RestoreReport
	local exeRestored = backup.restore(location.exe, backup.LEGACY_EXE)
	local tokensRestored = tokens.restore(location.versionDir)
	local pluginsRestored = plugins.restore(location.pluginDir)

	state.clear()

	return { exe = exeRestored, tokens = tokensRestored, plugins = pluginsRestored }
end

export type Step = {
	index: number,
	total: number,
	name: string,
	detail: string,
	progress: number,
}

export type ApplyOptions = {
	mode: mode.Mode,
	dryRun: boolean,
	report: (step: Step) -> (),
}

export type ApplyReport = {
	spec: string,
	mode: mode.Mode,
	version: string,
	dryRun: boolean,
	exe: {
		bypassPatched: number,
		bypassAlreadyPatched: number,
		redirectPatched: number,
		written: boolean,
	},
	tokens: tokens.Report,
	plugins: plugins.Report,
}

export type StatusReport = {
	version: string,
	lastApplied: state.State?,
	updatedSinceApply: boolean,
	bypassGates: number,
	bypassPatched: number,
	bypassError: string?,
	redirectStock: number,
	redirectRedirected: number,
	qtDarkSpec: string?,
	qtLightSpec: string?,
	qtPresent: boolean,
	tokensPristine: number,
	tokensTotal: number,
	pluginsPristine: number,
	pluginsTotal: number,
}

export type RestoreReport = {
	exe: boolean,
	tokens: number,
	plugins: number,
}

return pipeline

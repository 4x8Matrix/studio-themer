--> The terminal wizard `studio-themer` opens when run bare: locate Studio, pick a theme from a list, pick the slot
--> mode, confirm, watch the layers apply on a gauge, read the result. Same screen skeleton and key handling as create_app's
--> createWizard; the pipeline's step reports drive the gauge.

local StdPolyfills = require("../../luau_packages/std_polyfills")
local tui = require("../../luau_packages/cli_tui")

local pipeline = require("../pipeline")
local locate = require("../studio/locate")
local mapper = require("../theme/mapper")
local mode = require("../theme/mode")

local GRAY = 245
local WHITE = 255
local DARK_GRAY = 238
local MAUVE = 141
local BLUE = 111
local GREEN = 114
local RED = 203

local SIDEBAR_WIDTH = 30
local MIN_WIDTH = 80
local MIN_HEIGHT = 20
local FRAME_SECONDS = 0.05
local SCREENS = { "prereqs", "pick", "mode", "confirm", "loading", "done", "error" }
local MODE_ITEMS = {
	"both    dark and light slots take the theme",
	"dark    only the dark slot; light keeps what it has",
	"light   only the light slot; dark keeps what it has",
}
local ESCAPE = "\27"
local CONTROL_C = "\3"

local block = tui.block
local paragraph = tui.paragraph
local popup = tui.popup
local gauge = tui.gauge
local list = tui.list
local layout = tui.layout
local constraint = tui.constraint
local step = tui.step

local wizard = {
	SCREENS = SCREENS,
}

local function bordered(color: number): tui.BlockBuilder
	return block
		.new()
		:setBorders({ top = true, bottom = true, left = true, right = true })
		:setBorderSet("rounded")
		:setBorderForegroundColor(color)
end

function wizard.items(): { string }
	local items = {}

	for _, spec in mapper.knownSpecs() do
		table.insert(items, `{spec}{if mapper.isPalette(spec) then "" else "  (transform)"}`)
	end

	return items
end

function wizard.sidebarText(
	location: locate.Location?,
	currentDark: string?,
	currentLight: string?,
	chosen: string?,
	chosenMode: string?
): string
	local lines = {
		`Studio    {if location then location.version else "not found"}`,
		`Dark      {currentDark or "stock"}`,
		`Light     {currentLight or "stock"}`,
		`Chosen    {chosen or "-"}`,
		`Mode      {chosenMode or "-"}`,
		"",
		"Layers",
		"  bypass",
		"  redirect",
		"  qt-theme",
		"  tokens",
		"  plugins",
	}

	return table.concat(lines, "\n")
end

function wizard.run()
	local location = locate.locate({})
	local currentDark: string?
	local currentLight: string?

	if location then
		local status = pipeline.status(location)
		currentDark = status.qtDarkSpec
		currentLight = status.qtLightSpec
	end

	local specs = mapper.knownSpecs()
	local items = wizard.items()
	local selected = if currentDark then table.find(specs, currentDark) or 1 else 1
	local selectedMode = 1
	local screen = if location then "pick" else "prereqs"
	local running = true
	local chosen: string?
	local chosenMode: mode.Mode?

	local progress = 0.0
	local progressTarget = 0.0
	local statusMessage = "Starting"
	local applyDone = false
	local applyError: string?
	local loadingFrames = 0

	local function restoreTerminal()
		StdPolyfills.io.stdoutWrite("\27[?1049l\27[?25h")
		StdPolyfills.io.terminal.restoreMode()
	end

	StdPolyfills.io.terminal.enableRawMode()
	StdPolyfills.io.stdoutWrite("\27[?1049h\27[?25l")
	StdPolyfills.process.onSignal("INT", function()
		running = false
		restoreTerminal()
	end)

	local function startApply()
		screen = "loading"

		StdPolyfills.task.spawn(function()
			local ok, result, applyMessage = pcall(pipeline.apply, chosen :: string, location :: locate.Location, {
				mode = chosenMode :: mode.Mode,
				dryRun = false,
				report = function(reportStep: pipeline.Step)
					statusMessage = `[{reportStep.index}/{reportStep.total}] {reportStep.name}  {reportStep.detail}`
					progressTarget = reportStep.progress
				end,
			})

			if not ok then
				applyError = tostring(result)
			elseif not result then
				applyError = tostring(applyMessage)
			end

			applyDone = true
		end)
	end

	StdPolyfills.task.spawn(function()
		while running do
			local character = StdPolyfills.io.stdinRead(1)

			if not character or #character == 0 then
				StdPolyfills.task.wait(0.01)

				continue
			end

			if character == CONTROL_C then
				running = false

				continue
			end

			if screen == "done" or screen == "error" or screen == "prereqs" then
				running = false

				continue
			end

			if screen == "loading" then
				continue
			end

			if character == ESCAPE then
				local nextCharacter = StdPolyfills.io.stdinRead(1)

				if nextCharacter == "[" then
					local escapeCode = StdPolyfills.io.stdinRead(1)

					if screen == "pick" then
						if escapeCode == "A" and selected > 1 then
							selected -= 1
						elseif escapeCode == "B" and selected < #items then
							selected += 1
						end
					elseif screen == "mode" then
						if escapeCode == "A" and selectedMode > 1 then
							selectedMode -= 1
						elseif escapeCode == "B" and selectedMode < #MODE_ITEMS then
							selectedMode += 1
						end
					elseif screen == "confirm" and escapeCode == "A" then
						screen = "mode"
					end
				end

				continue
			end

			if screen == "pick" then
				if character == "\r" or character == "\n" then
					chosen = specs[selected]
					screen = "mode"
				elseif character == "j" and selected < #items then
					selected += 1
				elseif character == "k" and selected > 1 then
					selected -= 1
				end

				continue
			end

			if screen == "mode" then
				if character == "\r" or character == "\n" then
					chosenMode = mode.MODES[selectedMode] :: mode.Mode
					screen = "confirm"
				elseif character == "j" and selectedMode < #MODE_ITEMS then
					selectedMode += 1
				elseif character == "k" and selectedMode > 1 then
					selectedMode -= 1
				elseif character == "b" then
					screen = "pick"
				end

				continue
			end

			if screen == "confirm" then
				local lowercase = string.lower(character)

				if lowercase == "y" then
					startApply()
				elseif lowercase == "n" then
					screen = "mode"
				end
			end
		end
	end)

	while running do
		if screen == "loading" then
			local target = if applyDone then 1.0 else progressTarget

			loadingFrames += 1
			progress = progress + (target - progress) * 0.15

			if applyDone and loadingFrames >= 10 and progress >= 0.98 then
				progress = 1.0
				screen = if applyError then "error" else "done"
			end
		end

		local terminalWidth, terminalHeight = StdPolyfills.io.terminal.getSize()
		local renderContext = { width = terminalWidth or 80, height = terminalHeight or 24 }

		if (terminalWidth or 0) < MIN_WIDTH or (terminalHeight or 0) < MIN_HEIGHT then
			StdPolyfills.io.stdoutWrite(step(renderContext, function(fullArea)
				local tooSmall = paragraph
					.new()
					:setText(
						`window must be at least {MIN_WIDTH}x{MIN_HEIGHT}, currently {terminalWidth or 0}x{terminalHeight or 0}`
					)
					:setAlignment("center")
					:setStyle(RED)

				return { { widget = tooSmall, area = fullArea } }
			end))
			StdPolyfills.task.wait(FRAME_SECONDS)

			continue
		end

		StdPolyfills.io.stdoutWrite(step(renderContext, function(fullArea)
			local outerLayout = layout
				.new()
				:setDirection("vertical")
				:setConstraints({ constraint.length(3), constraint.fill(1), constraint.length(3) })
				:split(fullArea)
			local headerArea = outerLayout[1]
			local bodyArea = outerLayout[2]
			local footerArea = outerLayout[3]

			local headerBlock = bordered(MAUVE)
			local headerText = paragraph
				.new()
				:setText("studio-themer  ·  theme every layer of Roblox Studio")
				:setAlignment("center")
				:setStyle(WHITE)
			local footerBlock = bordered(GRAY)
			local footerHint = if screen == "prereqs"
				then "Press any key to exit"
				elseif screen == "pick" then "↑ ↓  choose  ·  Enter  continue  ·  Ctrl+C  cancel"
				elseif screen == "mode" then '↑ ↓  choose  ·  Enter  continue  ·  "b"  back  ·  Ctrl+C  cancel'
				elseif screen == "confirm" then '"y"  apply  ·  "n"  go back  ·  Ctrl+C  cancel'
				elseif screen == "loading" then "Applying, please wait…"
				else "Press any key to exit"
			local footerText = paragraph.new():setText(footerHint):setAlignment("center"):setStyle(GRAY)

			local widgets: { any } = {
				{ widget = headerBlock, area = headerArea },
				{ widget = headerText, area = headerBlock:inner(headerArea) },
				{ widget = footerBlock, area = footerArea },
				{ widget = footerText, area = footerBlock:inner(footerArea) },
			}

			if screen == "prereqs" then
				local prereqBlock = bordered(RED)
					:addTitle({ text = " Studio not found ", alignment = "center" })
					:setPadding({ left = 3, right = 3, top = 1, bottom = 1 })
				local prereqText = paragraph
					.new()
					:setText(
						"No Roblox Studio install was found under a Wine prefix.\n\n"
							.. "Tried WINEPREFIX and:\n  "
							.. table.concat(locate.candidates(), "\n  ")
							.. "\n\nRun `studio-themer apply --prefix <path> <theme>` to point at one."
					)
					:setStyle(RED)
					:setWrap(true)

				table.insert(widgets, { widget = prereqBlock, area = bodyArea })
				table.insert(widgets, { widget = prereqText, area = prereqBlock:inner(bodyArea) })
			elseif screen == "pick" or screen == "mode" or screen == "confirm" then
				local bodyLayout = layout
					.new()
					:setDirection("horizontal")
					:setConstraints({ constraint.length(SIDEBAR_WIDTH), constraint.fill(1) })
					:split(bodyArea)
				local sidebarArea = bodyLayout[1]
				local mainArea = bodyLayout[2]

				local sidebarBlock = bordered(GRAY):addTitle({ text = " Install ", alignment = "center" })
				local sidebarText = paragraph
					.new()
					:setText(wizard.sidebarText(location, currentDark, currentLight, chosen, chosenMode))
					:setStyle(GRAY)

				table.insert(widgets, { widget = sidebarBlock, area = sidebarArea })
				table.insert(widgets, { widget = sidebarText, area = sidebarBlock:inner(sidebarArea) })

				local isModeStep = screen ~= "pick"
				local pickBlock = bordered(BLUE):addTitle({
					text = if isModeStep then ` Mode for {chosen} ` else " Theme ",
					alignment = "left",
				})
				local themeList = list.new()
					:setItems(if isModeStep then MODE_ITEMS else items)
					:setSelected(if isModeStep then selectedMode else selected)
					:setHighlightSymbol("▶ ")
					:setStyle(WHITE)
					:setHighlightStyle(WHITE, DARK_GRAY)

				table.insert(widgets, { widget = pickBlock, area = mainArea })
				table.insert(widgets, { widget = themeList, area = pickBlock:inner(mainArea) })

				if screen == "confirm" then
					local confirmPopup = popup
						.new()
						:setWidth(58)
						:setHeight(11)
						:setBorderSet("rounded")
						:setBorderForegroundColor(MAUVE)
						:addTitle({ text = " Confirm ", alignment = "center" })
						:setPadding({ left = 2, right = 2, top = 1, bottom = 1 })
					local confirmArea = confirmPopup:area(bodyArea)
					local confirmText = paragraph
						.new()
						:setText(
							`Apply {chosen} ({mode.describe(chosenMode :: mode.Mode)}) to {(location :: locate.Location).version}?\n\n`
								.. "Every layer is rewritten from its pristine copy.\n"
								.. "Studio must be fully quit for the change to show.\n\n"
								.. '  "y"  apply    "n"  go back'
						)
						:setStyle(WHITE)
						:setWrap(true)

					table.insert(widgets, { widget = confirmPopup, area = confirmArea })
					table.insert(widgets, { widget = confirmText, area = confirmPopup:inner(confirmArea) })
				end
			elseif screen == "loading" then
				local loadingBlock = bordered(BLUE)
					:addTitle({ text = ` Applying {chosen} `, alignment = "center" })
					:setPadding({ left = 3, right = 3, top = 1, bottom = 1 })
				local loadingInner = loadingBlock:inner(bodyArea)
				local loadingLayout = layout
					.new()
					:setDirection("vertical")
					:setConstraints({
						constraint.fill(1),
						constraint.length(3),
						constraint.length(1),
						constraint.fill(1),
					})
					:split(loadingInner)
				local percent = math.floor(progress * 100)
				local loadingGauge = gauge
					.new()
					:setRatio(progress)
					:setLabel(`{percent}%`)
					:setStyle(GRAY)
					:setFilledStyle(WHITE, MAUVE)
					:setBlock(bordered(BLUE))
				local statusText = paragraph
					.new()
					:setText(if applyDone then "Finishing…" else statusMessage)
					:setAlignment("center")
					:setStyle(GRAY)

				table.insert(widgets, { widget = loadingBlock, area = bodyArea })
				table.insert(widgets, { widget = loadingGauge, area = loadingLayout[2] })
				table.insert(widgets, { widget = statusText, area = loadingLayout[3] })
			else
				local isError = screen == "error"
				local resultBlock = bordered(if isError then RED else GREEN)
					:addTitle({ text = if isError then " Error " else " Done ", alignment = "center" })
					:setPadding({ left = 3, right = 3, top = 1, bottom = 1 })
				local resultContent = if isError
					then `An error occurred:\n\n{applyError or "unknown error"}`
					else `Applied {chosen} across every layer.\n\n`
						.. "Fully quit and restart Studio to see it.\n"
						.. "Run `studio-themer status` any time to check the install,\n"
						.. "and `studio-themer restore` to put stock back."
				local resultText =
					paragraph.new():setText(resultContent):setStyle(if isError then RED else WHITE):setWrap(true)

				table.insert(widgets, { widget = resultBlock, area = bodyArea })
				table.insert(widgets, { widget = resultText, area = resultBlock:inner(bodyArea) })
			end

			return widgets
		end))

		StdPolyfills.task.wait(FRAME_SECONDS)
	end

	restoreTerminal()

	if applyError then
		StdPolyfills.io.stderrWrite(`\n\27[1;31m── Apply Error ──\27[0m\n{applyError}\n\n`)
	end
end

return wizard

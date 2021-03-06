---------------------------------------------------------------------------------------------------
-- Proposal: https://github.com/smartdevicelink/sdl_evolution/blob/master/proposals/0041-appicon-resumption.md
-- User story:TBD
-- Use case:TBD
--
-- Requirement summary:
-- TBD
--
-- Description:
-- In case:
-- 1) SDL, HMI are started.
-- 2) App1 set custom icon via putfile and SetAppIcon requests.
-- 3) App2 set custom icon via putfile and SetAppIcon requests.
-- 4) Two app are re-registered.
-- SDL does:
-- 1) Register an App 1 successfully, respond to RAI with result code "SUCCESS", "iconResumed" = true.
-- 2) Register an App 2 successfully, respond to RAI with result code "SUCCESS", "iconResumed" = true.
---------------------------------------------------------------------------------------------------
--[[ Required Shared libraries ]]
local runner = require('user_modules/script_runner')
local common = require('test_scripts/API/SetAppIcon/commonIconResumed')

--[[ Test Configuration ]]
runner.testSettings.isSelfIncluded = false

--[[ Local Variables ]]
local IconValueForApp1 = "icon.png"
local allParamsApp1 = {
  requestParams = {
  syncFileName = IconValueForApp1
 },
  requestUiParams = {
    syncFileName = {
      imageType = "DYNAMIC",
      value = common.getPathToFileInStorage(IconValueForApp1)
    }
  }
}

local IconValueForApp2 = "action.png"
local allParamsApp2 = {
  requestParams = {
    syncFileName = IconValueForApp2
  },
  requestUiParams = {
    syncFileName = {
      imageType = "DYNAMIC",
      value = common.getPathToFileInStorage(IconValueForApp2, 2)
    }
  }
}

local PutFileParams = {
  syncFileName = IconValueForApp2,
  fileType = "GRAPHIC_PNG",
}

--[[ Scenario ]]
runner.Title("Preconditions")
runner.Step("Clean environment", common.preconditions)
runner.Step("Start SDL, HMI, connect Mobile, start Session", common.start)

runner.Title("Test")
runner.Step("App1 registration with iconResumed = false", common.registerAppWOPTU, { 1, false })
runner.Step("Upload icon file", common.putFile)
runner.Step("SetAppIcon", common.setAppIcon, { allParamsApp1 } )

runner.Step("App2 registration with iconResumed = false", common.registerAppWOPTU, { 2, false })
runner.Step("Upload icon file", common.putFile, { PutFileParams, nil, 2 })
runner.Step("SetAppIcon", common.setAppIcon, { allParamsApp2, 2 } )

runner.Step("App1 unregistration", common.unregisterAppInterface, { 1 })
runner.Step("App2 unregistration", common.unregisterAppInterface, { 2 })

runner.Step("App1 registration with iconResumed = true", common.registerAppWOPTU, { 1, true, true })
runner.Step("App2 registration with iconResumed = true", common.registerAppWOPTU, { 2, true, true })

runner.Title("Postconditions")
runner.Step("Stop SDL", common.postconditions)

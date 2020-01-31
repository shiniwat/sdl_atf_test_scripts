--  Requirement summary:
--  [HMILevel Resumption]: Conditions to resume app to FULL in the next ignition cycle
--
--  Description:
--  Check that SDL does not perform App resumption in case when app is
--  registered in more than 30 sec. after BC.OnReady from HMI in the very next ignition cycle
--
--  1. Used precondition
--  Media App is registered and active on HMI
--
--  2. Performed steps
--  Send IGNITION_OFF from HMI.
--  Start SDL.
--  Wait 30 seconds and turn on transport.
--
--  Expected behavior:
--  1. SDL sends to HMI OnSDLClose.
--     App is registered successfully and get default HMI level.
---------------------------------------------------------------------------------------------------

--[[ Required Shared libraries ]]
local runner = require('user_modules/script_runner')
local common = require('test_scripts/Smoke/commonSmoke')

--[[ Test Configuration ]]
runner.testSettings.isSelfIncluded = false

-- [[ Local Functions ]]
local function expAppUnregistered()
  common.getMobileSession():ExpectNotification("OnAppInterfaceUnregistered", { reason = "IGNITION_OFF" })
  common.getHMIConnection():ExpectNotification("BasicCommunication.OnAppUnregistered", { unexpectedDisconnect = false })
end

local function expResData()
  common.getHMIConnection():ExpectRequest("VR.AddCommand", common.resParams.AddCommand.hmi)
  :Do(function(_, data)
      common.getHMIConnection():SendResponse(data.id, data.method, "SUCCESS")
    end)
  common.getHMIConnection():ExpectRequest("UI.AddSubMenu", common.resParams.AddSubMenu.hmi)
  :Do(function(_, data)
      common.getHMIConnection():SendResponse(data.id, data.method, "SUCCESS")
    end)
  common.getMobileSession():ExpectNotification("OnHashChange")
end

local function expResLvl()
  common.getHMIConnection():ExpectRequest("BasicCommunication.ActivateApp")
  :Times(0)
  common.getMobileSession():ExpectNotification("OnHMIStatus",
    { hmiLevel = "NONE", audioStreamingState = "NOT_AUDIBLE", systemContext = "MAIN" })
  :Times(1)
end

--[[ Scenario ]]
runner.Title("Preconditions")
runner.Step("Clean environment", common.preconditions)
runner.Step("Start SDL, HMI, connect Mobile, 1st cycle", common.start)
runner.Step("Register App", common.registerApp)
runner.Step("Activate App", common.activateApp)
runner.Step("Add Command", common.addCommand)
runner.Step("Add SubMenu", common.addSubMenu)

runner.Title("Test")
runner.Step("Ignition Off", common.ignitionOff, { expAppUnregistered })
runner.Step("Start SDL, HMI, connect Mobile, 2nd cycle", common.start)
runner.Step("Wait 31 sec", common.wait, { 31000 })
runner.Step("ReRegister App", common.reregisterApp, { "SUCCESS", expResData, expResLvl })

runner.Title("Postconditions")
runner.Step("Stop SDL", common.postconditions)

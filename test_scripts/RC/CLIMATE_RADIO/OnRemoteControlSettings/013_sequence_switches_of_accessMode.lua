---------------------------------------------------------------------------------------------------
-- User story: https://github.com/smartdevicelink/sdl_requirements/issues/10
-- Use case: https://github.com/smartdevicelink/sdl_requirements/blob/master/detailed_docs/resource_allocation.md
-- Item: Use Case 1: Main Flow
--
-- User story: https://github.com/smartdevicelink/sdl_requirements/issues/10
-- Use case: https://github.com/smartdevicelink/sdl_requirements/blob/master/detailed_docs/resource_allocation.md
-- Item: Use Case 1: Alternative flow 1
--
-- User story: https://github.com/smartdevicelink/sdl_requirements/issues/10
-- Use case: https://github.com/smartdevicelink/sdl_requirements/blob/master/detailed_docs/resource_allocation.md
-- Item: Use Case 1: Alternative flow 2
--
-- Requirement summary:
-- [SDL_RC] Resource allocation based on access mode
--
-- Description:
-- In case:
-- RC_functionality is disabled on HMI and HMI sends notification OnRemoteControlSettings (allowed:true, <any_accessMode>)
--
-- SDL must:
-- 1) store RC state allowed:true and received from HMI internally
-- 2) allow RC functionality for applications with REMOTE_CONTROL appHMIType
--
-- Additional checks:
-- - Switch RA access mode Default -> ASK_DRIVER
-- - Switch RA access mode ASK_DRIVER -> AUTO_ALLOW
-- - Switch RA access mode AUTO_ALLOW -> AUTO_DENY
-- - Switch RA access mode AUTO_DENY -> ASK_DRIVER
-- - Switch RA access mode DASK_DRIVER -> AUTO_DENY
-- - Switch RA access mode AUTO_DENY -> AUTO_ALLOW
-- - Switch RA access mode AUTO_ALLOW -> ASK_DRIVER
---------------------------------------------------------------------------------------------------
--[[ Required Shared libraries ]]
local runner = require('user_modules/script_runner')
local commonRC = require('test_scripts/RC/commonRC')

--[[ Local Variables ]]
local modules = { "CLIMATE", "RADIO" }

local rcRpcs = { "SetInteriorVehicleData", "ButtonPress" }

--[[ Local Functions ]]

local function ptu_update_func(tbl)
  tbl.policy_table.app_policies[config.application2.registerAppInterfaceParams.appID] = commonRC.getRCAppConfig()
end

--[[ Scenario ]]
runner.Title("Preconditions")
runner.Step("Clean environment", commonRC.preconditions)
runner.Step("Start SDL, HMI, connect Mobile, start Session", commonRC.start)
runner.Step("RAI1, PTU", commonRC.rai_ptu, { ptu_update_func })
runner.Step("RAI2", commonRC.rai_n, { 2 })

runner.Title("Test")
runner.Title("Default -> ASK_DRIVER")
runner.Step("Enable RC from HMI with ASK_DRIVER access mode", commonRC.defineRAMode, { true, "ASK_DRIVER"})
for _, mod in pairs(modules) do
	runner.Step("Activate App2", commonRC.activate_app, { 2 })
	runner.Step("Check module " .. mod .." App2 SetInteriorVehicleData allowed", commonRC.rpcAllowed, { mod, 2, "SetInteriorVehicleData" })
  runner.Step("Activate App1", commonRC.activate_app)
  runner.Step("Check module " .. mod .." App1 SetInteriorVehicleData allowed with driver consent", commonRC.rpcAllowedWithConsent, { mod, 1, "SetInteriorVehicleData" })
  runner.Step("Activate App2", commonRC.activate_app, { 2 })
  runner.Step("Check module " .. mod .." App1 ButtonPress allowed with driver consent", commonRC.rpcAllowedWithConsent, { mod, 2, "ButtonPress" })
  runner.Step("Activate App1", commonRC.activate_app)
  runner.Step("Check module " .. mod .." App1 ButtonPress allowed with driver consent", commonRC.rpcAllowedWithConsent, { mod, 1, "ButtonPress" })
end
runner.Title("ASK_DRIVER -> AUTO_ALLOW")
runner.Step("Enable RC from HMI with AUTO_ALLOW access mode", commonRC.defineRAMode, { true, "AUTO_ALLOW"})
for _, mod in pairs(modules) do
  for _, rpc in pairs(rcRpcs) do
  	runner.Step("Activate App2", commonRC.activate_app, { 2 })
    runner.Step("Check module " .. mod .." App2 " .. rpc .. " allowed", commonRC.rpcAllowed, { mod, 2, rpc })
    runner.Step("Activate App1", commonRC.activate_app)
    runner.Step("Check module " .. mod .." App1 " .. rpc .. " allowed", commonRC.rpcAllowed, { mod, 1, rpc })
  end
end
runner.Title("AUTO_ALLOW -> AUTO_DENY")
runner.Step("Enable RC from HMI with AUTO_DENY access mode", commonRC.defineRAMode, { true, "AUTO_DENY"})
for _, mod in pairs(modules) do
  for _, rpc in pairs(rcRpcs) do
    runner.Step("Activate App2", commonRC.activate_app, { 2 })
    runner.Step("Check module " .. mod .." App2 " .. rpc .. " denied", commonRC.rpcDenied, { mod, 2, rpc, "IN_USE" })
    runner.Step("Activate App1", commonRC.activate_app)
    runner.Step("Check module " .. mod .." App1 " .. rpc .. " allowed", commonRC.rpcAllowed, { mod, 1, rpc })
  end
end
runner.Title("AUTO_DENY -> ASK_DRIVER")
runner.Step("Enable RC from HMI with ASK_DRIVER access mode", commonRC.defineRAMode, { true, "ASK_DRIVER"})
for _, mod in pairs(modules) do
	runner.Step("Activate App2", commonRC.activate_app, { 2 })
	runner.Step("Check module " .. mod .." App2 SetInteriorVehicleData allowed with driver consent", commonRC.rpcAllowedWithConsent, { mod, 2, "SetInteriorVehicleData" })
  runner.Step("Activate App1", commonRC.activate_app)
  runner.Step("Check module " .. mod .." App1 SetInteriorVehicleData allowed with driver consent", commonRC.rpcAllowedWithConsent, { mod, 1, "SetInteriorVehicleData" })
  runner.Step("Activate App2", commonRC.activate_app, { 2 })
  runner.Step("Check module " .. mod .." App1 ButtonPress allowed with driver consent", commonRC.rpcAllowedWithConsent, { mod, 2, "ButtonPress" })
  runner.Step("Activate App1", commonRC.activate_app)
  runner.Step("Check module " .. mod .." App1 ButtonPress allowed with driver consent", commonRC.rpcAllowedWithConsent, { mod, 1, "ButtonPress" })
end
runner.Title("ASK_DRIVER -> AUTO_DENY")
runner.Step("Enable RC from HMI with AUTO_DENY access mode", commonRC.defineRAMode, { true, "AUTO_DENY"})
for _, mod in pairs(modules) do
  for _, rpc in pairs(rcRpcs) do
    runner.Step("Activate App2", commonRC.activate_app, { 2 })
    runner.Step("Check module " .. mod .." App2 " .. rpc .. " denied", commonRC.rpcDenied, { mod, 2, rpc, "IN_USE" })
    runner.Step("Activate App1", commonRC.activate_app)
    runner.Step("Check module " .. mod .." App1 " .. rpc .. " allowed", commonRC.rpcAllowed, { mod, 1, rpc })
  end
end
runner.Title("AUTO_DENY -> AUTO_ALLOW")
runner.Step("Enable RC from HMI with AUTO_ALLOW access mode", commonRC.defineRAMode, { true, "AUTO_ALLOW"})
for _, mod in pairs(modules) do
  for _, rpc in pairs(rcRpcs) do
  	runner.Step("Activate App2", commonRC.activate_app, { 2 })
    runner.Step("Check module " .. mod .." App2 " .. rpc .. " allowed", commonRC.rpcAllowed, { mod, 2, rpc })
    runner.Step("Activate App1", commonRC.activate_app)
    runner.Step("Check module " .. mod .." App1 " .. rpc .. " allowed", commonRC.rpcAllowed, { mod, 1, rpc })
  end
end
runner.Title("AUTO_ALLOW -> ASK_DRIVER")
runner.Step("Enable RC from HMI with ASK_DRIVER access mode", commonRC.defineRAMode, { true, "ASK_DRIVER"})
for _, mod in pairs(modules) do
	runner.Step("Activate App2", commonRC.activate_app, { 2 })
	runner.Step("Check module " .. mod .." App2 SetInteriorVehicleData allowed with driver consent", commonRC.rpcAllowedWithConsent, { mod, 2, "SetInteriorVehicleData" })
  runner.Step("Activate App1", commonRC.activate_app)
  runner.Step("Check module " .. mod .." App1 SetInteriorVehicleData allowed with driver consent", commonRC.rpcAllowedWithConsent, { mod, 1, "SetInteriorVehicleData" })
  runner.Step("Activate App2", commonRC.activate_app, { 2 })
  runner.Step("Check module " .. mod .." App1 ButtonPress allowed with driver consent", commonRC.rpcAllowedWithConsent, { mod, 2, "ButtonPress" })
  runner.Step("Activate App1", commonRC.activate_app)
  runner.Step("Check module " .. mod .." App1 ButtonPress allowed with driver consent", commonRC.rpcAllowedWithConsent, { mod, 1, "ButtonPress" })
end

runner.Title("Postconditions")
runner.Step("Stop SDL", commonRC.postconditions)
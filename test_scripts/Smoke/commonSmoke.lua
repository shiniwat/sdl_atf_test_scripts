---------------------------------------------------------------------------------------------------
-- Smoke API common module
---------------------------------------------------------------------------------------------------

--[[ General configuration parameters ]]
config.deviceMAC = "12ca17b49af2289436f303e0166030a21e525d266e209267433801a8fd4071a0"
config.defaultProtocolVersion = 2

--[[ Required Shared libraries ]]
local mobile_session = require("mobile_session")
local json = require("modules/json")

local consts = require("user_modules/consts")
local commonFunctions = require("user_modules/shared_testcases/commonFunctions")
local commonSteps = require("user_modules/shared_testcases/commonSteps")
local commonTestCases = require("user_modules/shared_testcases/commonTestCases")
local commonPreconditions = require('user_modules/shared_testcases/commonPreconditions')

-- local mobile_api_loader = require("modules/api_loader")
-- local mobile_api = mobile_api_loader.init("data/MOBILE_API.xml")
-- local mobile_api_schema = mobile_api.interface["Ford Sync RAPI"]

-- local hmi_api_loader = require("modules/api_loader")
-- local hmi_api = hmi_api_loader.init("data/HMI_API.xml")
-- local hmi_api_schema = hmi_api.interface["Common"]

--[[ Local Variables ]]
local ptu_table = {}
local hmiAppIds = {}

local commonSmoke = {}

commonSmoke.timeout = 5000
commonSmoke.minTimeout = 500

local function allowSDL(self)
  self.hmiConnection:SendNotification("SDL.OnAllowSDLFunctionality",
    { allowed = true, source = "GUI", device = { id = config.deviceMAC, name = "127.0.0.1" } })
end

local function jsonFileToTable(pFileName)
  local f = io.open(pFileName, "r")
  local content = f:read("*all")
  f:close()
  return json.decode(content)
end

local function checkIfPTSIsSentAsBinary(bin_data)
  if not (bin_data ~= nil and string.len(bin_data) > 0) then
    commonFunctions:userPrint(consts.color.red,
      "PTS was not sent to Mobile in payload of OnSystemRequest")
  end
end

local function getPTUFromPTS(tbl)
  tbl.policy_table.consumer_friendly_messages.messages = nil
  tbl.policy_table.device_data = nil
  tbl.policy_table.module_meta = nil
  tbl.policy_table.usage_and_error_counts = nil
  tbl.policy_table.functional_groupings["DataConsent-2"].rpcs = json.null
  tbl.policy_table.module_config.preloaded_pt = nil
  tbl.policy_table.module_config.preloaded_date = nil
end

local function ptu(self, id, pUpdateFunction)
  local function getAppsCount()
    local count = 0
    for _ in pairs(hmiAppIds) do
      count = count + 1
    end
    return count
  end

  local policy_file_name = "PolicyTableUpdate"
  local policy_file_path = commonFunctions:read_parameter_from_smart_device_link_ini("SystemFilesPath")
  local pts_file_name = commonFunctions:read_parameter_from_smart_device_link_ini("PathToSnapshot")
  local ptu_file_name = os.tmpname()
  local requestId = self.hmiConnection:SendRequest("SDL.GetURLS", { service = 7 })
  EXPECT_HMIRESPONSE(requestId)
  :Do(function()
      self.hmiConnection:SendNotification("BasicCommunication.OnSystemRequest",
        { requestType = "PROPRIETARY", fileName = pts_file_name })
      getPTUFromPTS(ptu_table)
      local function updatePTU(tbl)
        tbl.policy_table.app_policies[commonSmoke.getMobileAppId(id)] = commonSmoke.getSmokeAppPoliciesConfig()
      end
      updatePTU(ptu_table)
      if pUpdateFunction then
        pUpdateFunction(ptu_table)
      end
      local function tableToJsonFile(tbl, file_name)
        local f = io.open(file_name, "w")
        f:write(json.encode(tbl))
        f:close()
      end
      tableToJsonFile(ptu_table, ptu_file_name)

      local event = events.Event()
      event.matches = function(self, e) return self == e end
      EXPECT_EVENT(event, "PTU event")
      :Timeout(11000)

      for id = 1, getAppsCount() do
        local mobileSession = commonSmoke.getMobileSession(id, self)
        mobileSession:ExpectNotification("OnSystemRequest", { requestType = "PROPRIETARY" })
        :Do(function(_, data)
            print("App ".. id .. " was used for PTU")
            RAISE_EVENT(event, event, "PTU event")
            checkIfPTSIsSentAsBinary(data.binaryData)
            local corIdSystemRequest = mobileSession:SendRPC("SystemRequest", { requestType = "PROPRIETARY", fileName = policy_file_name }, ptu_file_name)
            EXPECT_HMICALL("BasicCommunication.SystemRequest")
            :Do(function(_, data)
                self.hmiConnection:SendResponse(data.id, "BasicCommunication.SystemRequest", "SUCCESS", { })
                self.hmiConnection:SendNotification("SDL.OnReceivedPolicyUpdate",
                  { policyfile = policy_file_path .. "/" .. policy_file_name })
              end)
            mobileSession:ExpectResponse(corIdSystemRequest, { success = true, resultCode = "SUCCESS" })
            :Do(function() os.remove(ptu_file_name) end)
          end)
        :Times(AtMost(1))
      end
    end)
end

--[[Module functions]]

function commonSmoke.preconditions()
  commonFunctions:SDLForceStop()
  commonSteps:DeletePolicyTable()
  commonSteps:DeleteLogsFiles()
end

function commonSmoke.getDeviceMAC()
  return config.deviceMAC
end

function commonSmoke.getPathToSDL()
  return config.pathToSDL
end

function commonSmoke.getMobileAppId(pAppId)
  if not pAppId then pAppId = 1 end
  return config["application" .. pAppId].registerAppInterfaceParams.appID
end

function commonSmoke.getSelfAndParams(...)
  local out = { }
  local selfIdx = nil
  for i,v in pairs({...}) do
    if type(v) == "table" and v.isTest then
      table.insert(out, v)
      selfIdx = i
      break
    end
  end
  local idx = 2
  for i = 1, table.maxn({...}) do
    if i ~= selfIdx then
      out[idx] = ({...})[i]
      idx = idx + 1
    end
  end
  return table.unpack(out, 1, table.maxn(out))
end

function commonSmoke.getPathToFileInStorage(fileName)
  return commonSmoke.getPathToSDL() .. "storage/"
    .. commonSmoke.getMobileAppId() .. "_"
    .. commonSmoke.getDeviceMAC() .. "/"  .. fileName
end

function commonSmoke.getMobileSession(pAppId, self)
  self, pAppId = commonSmoke.getSelfAndParams(pAppId, self)
  if not pAppId then pAppId = 1 end
  return self["mobileSession" .. pAppId]
end

function commonSmoke.getSmokeAppPoliciesConfig()
  return {
    keep_context = false,
    steal_focus = false,
    priority = "NONE",
    default_hmi = "NONE",
    groups = { "Base-4" }
  }
end

function commonSmoke.splitString(inputStr, sep)
    if sep == nil then
        sep = "%s"
    end
    local splitted, i = {}, 1
    for str in string.gmatch(inputStr, "([^"..sep.."]+)") do
        splitted[i] = str
        i = i + 1
    end
    return splitted
end

function commonSmoke.activateApp(pAppId, self)
  self, pAppId = commonSmoke.getSelfAndParams(pAppId, self)
  if not pAppId then pAppId = 1 end
  local pHMIAppId = hmiAppIds[config["application" .. pAppId].registerAppInterfaceParams.appID]
  local mobSession = commonSmoke.getMobileSession(pAppId, self)
  local requestId = self.hmiConnection:SendRequest("SDL.ActivateApp", { appID = pHMIAppId })
  EXPECT_HMIRESPONSE(requestId)
  mobSession:ExpectNotification("OnHMIStatus",
    {hmiLevel = "FULL", audioStreamingState = "AUDIBLE", systemContext = "MAIN"})
  commonTestCases:DelayedExp(commonSmoke.minTimeout)
end

function commonSmoke.start(pHMIParams, self)
  self, pHMIParams = commonSmoke.getSelfAndParams(pHMIParams, self)
  self:runSDL()
  commonFunctions:waitForSDLStart(self)
  :Do(function()
      self:initHMI(self)
      :Do(function()
          commonFunctions:userPrint(consts.color.magenta, "HMI initialized")
          self:initHMI_onReady(pHMIParams)
          :Do(function()
              commonFunctions:userPrint(consts.color.magenta, "HMI is ready")
              self:connectMobile()
              :Do(function()
                  commonFunctions:userPrint(consts.color.magenta, "Mobile connected")
                  allowSDL(self)
                end)
            end)
        end)
    end)
end

function commonSmoke.registerApplicationWithPTU(pAppId, pUpdateFunction, self)
  self, pAppId, pUpdateFunction = commonSmoke.getSelfAndParams(pAppId, pUpdateFunction, self)
  if not pAppId then pAppId = 1 end
  self["mobileSession" .. pAppId] = mobile_session.MobileSession(self, self.mobileConnection)
  self["mobileSession" .. pAppId]:StartService(7)
  :Do(function()
      local corId = self["mobileSession" .. pAppId]:SendRPC("RegisterAppInterface",
        config["application" .. pAppId].registerAppInterfaceParams)
      EXPECT_HMINOTIFICATION("BasicCommunication.OnAppRegistered",
        { application = { appName = config["application" .. pAppId].registerAppInterfaceParams.appName } })
      :Do(function(_, data)
          hmiAppIds[config["application" .. pAppId].registerAppInterfaceParams.appID] = data.params.application.appID
          EXPECT_HMINOTIFICATION("SDL.OnStatusUpdate",
            {status = "UPDATE_NEEDED"}, {status = "UPDATING"}, {status = "UP_TO_DATE" })
          :Times(3)
          EXPECT_HMICALL("BasicCommunication.PolicyUpdate")
          :Do(function(_, data)
              self.hmiConnection:SendResponse(data.id, data.method, "SUCCESS", { })
              ptu_table = jsonFileToTable(data.params.file)
              ptu(self, pAppId, pUpdateFunction)
            end)
        end)
      self["mobileSession" .. pAppId]:ExpectResponse(corId, { success = true, resultCode = "SUCCESS" })
      :Do(function()
          self["mobileSession" .. pAppId]:ExpectNotification("OnHMIStatus",
            {hmiLevel = "NONE", audioStreamingState = "NOT_AUDIBLE", systemContext = "MAIN"})
          :Times(1)
          self["mobileSession" .. pAppId]:ExpectNotification("OnPermissionsChange")
          :Times(AtLeast(1)) -- todo: issue with SDL --> notification is sent twice
        end)
    end)
end

function commonSmoke.putFile(params, pAppId, self)
  if not pAppId then pAppId = 1 end
  local mobileSession = commonSmoke.getMobileSession(pAppId, self);
  local cid = mobileSession:SendRPC("PutFile", params.requestParams, params.filePath)

  mobileSession:ExpectResponse(cid, { success = true, resultCode = "SUCCESS"})
end

function commonSmoke.readParameterFromSmartDeviceLinkIni(paramName)
  return commonFunctions:read_parameter_from_smart_device_link_ini(paramName)
end

function commonSmoke.postconditions()
  StopSDL()
end

return commonSmoke
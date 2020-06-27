--include('autorun/bsp2.lua')


local Debug = true

-- SET UP GLOBAL VARIABLES

local GlobalRTSAngle = 45
local RTSMovementPlayers = {}
local ClippingPlaneHeight = 0
local RealTimeNow = math.ceil(RealTime())

-- ADD ACCESSORS TO VIEW INFORMATION

meta = FindMetaTable("Player")
AccessorFunc(meta, "rts_view_state", "RTSViewState", FORCE_BOOL)
AccessorFunc(meta, "rts_plane_height", "RTSPlaneHeight")
AccessorFunc(meta, "rts_eye_trace", "RTSEyeTrace")
AccessorFunc(meta, "rts_view_angle", "RTSViewAngle")

-- OVERRIDE EYETRACE FOR OTHER ADDONS

if !oldEyeTrace then

	oldEyeTrace = meta.GetEyeTrace

end

if !oldUtilTrace then

	oldUtilTrace = util.GetPlayerTrace

end

local RTSEyeTrace = function(self)
	if self:GetRTSViewState() then
		local trace = self:CalculateRTSEyeTrace()
		self:SetRTSEyeTrace(trace)
		return trace
	else
		return oldEyeTrace(self)
	end
end

local RTSUtilTrace = function(ply, dir)
	if ply:GetRTSViewState() then
		local trace = ply:CalculateRTSEyeTrace(true, dir)
		return trace
	else
		return oldUtilTrace(ply)
	end
end

function meta:GetEyeTrace()
	if CLIENT then
	debugoverlay.ScreenText(0.1,0.1, "rts eyetrace hitpos " .. tostring(self:CalculateRTSEyeTrace().HitPos), FrameTime(), Color(255,0,0))
	debugoverlay.ScreenText(0.1,0.11, "eye angles" .. tostring(self:EyeAngles()), FrameTime(), Color(255,0,0))
	debugoverlay.Cross(self:CalculateRTSEyeTrace().HitPos, 50, 0.1, Color(255,0,0))
	debugoverlay.Line(self:GetPos(), self:CalculateRTSEyeTrace().HitPos, 0.1, Color(255,0,0), false)
	debugoverlay.ScreenText(0.1,0.12, "plane dist from world origin " .. tostring(self:GetRTSPlaneHeight()), FrameTime(), Color(255,0,0))
	debugoverlay.ScreenText(0.1,0.13, "trace len " .. tostring(self:CalculateRTSEyeTrace().Fraction), FrameTime(), Color(255,0,0))
	end
	if SERVER then
	debugoverlay.ScreenText(0.1,0.14, "rts eyetrace hitpos " .. tostring(self:CalculateRTSEyeTrace().HitPos), FrameTime()*2, Color(0,255,0))
	debugoverlay.ScreenText(0.1,0.15, "eye angles" .. tostring(self:EyeAngles()), FrameTime()*2, Color(0,255,0))
	debugoverlay.Cross(self:CalculateRTSEyeTrace().HitPos, 50, 0.1, Color(0,255,0))
	debugoverlay.Line(self:GetPos(), self:CalculateRTSEyeTrace().HitPos, 0.1, Color(0,255,0), false)
	debugoverlay.ScreenText(0.1,0.16, "plane dist from world origin " .. tostring(self:GetRTSPlaneHeight()), FrameTime()*2, Color(0,255,0))
	debugoverlay.ScreenText(0.1,0.17, "trace len " .. tostring(self:CalculateRTSEyeTrace().Fraction), FrameTime()*2, Color(0,255,0))
	end
	return RTSEyeTrace(self)
end

function util.GetPlayerTrace(ply, dir)
	return RTSUtilTrace(ply, dir)
end

function meta:CalculateRTSEyeTrace(a, dir)
	if dir == nil then dir = self:GetAimVector() end
	if self:GetRTSViewState() then
		local angle = math.abs(90 - dir:Angle().x)
--		local localang = self:WorldToLocal(dir.Normal):Angle()
		local height = self:EyePos().z + self:GetRTSPlaneHeight()
		local dist = height / math.cos(math.rad(angle))
		local trVec = dir
		local eyeAng = self:EyeAngles():Forward()
--		local intersect = util.IntersectRayWithPlane(self:EyePos(), eyeAng, Vector(0,0,self:GetRTSPlaneHeight()), Vector(0,0,-1))
--		debugoverlay.Cross(intersect + trVec * dist, 50, 0.1, Color(0,0,255))
		local TraceData = {
			start = self:EyePos() + trVec * dist,
			endpos = self:EyePos() + trVec * dist + trVec * 16384
		}	
		local Trace = util.TraceLine(TraceData)

		debugoverlay.ScreenText(0.35,0.10, "eye height		 " .. self:EyePos().z, 												FrameTime(), Color(0,0,255))
		debugoverlay.ScreenText(0.35,0.11, "clip plane height" .. self:GetRTSPlaneHeight(), 									FrameTime(), Color(0,0,255))
		debugoverlay.ScreenText(0.35,0.12, "eyeAng			 " .. tostring(eyeAng), 											FrameTime(), Color(0,0,255))
		debugoverlay.ScreenText(0.35,0.13, "startpos		 " .. tostring(self:EyePos() + trVec * dist), 			FrameTime(), Color(0,0,255))
		debugoverlay.ScreenText(0.35,0.14, "endpos			 " .. tostring(self:EyePos() + trVec * dist + trVec * 36500), FrameTime(), Color(0,0,255))
		debugoverlay.ScreenText(0.35,0.15, "real endpos		 " .. tostring(Trace.HitPos), FrameTime(), Color(0,0,255))
		debugoverlay.ScreenText(0.35,0.16, "hit ent 		 " .. tostring(Trace.Entity), 										FrameTime(), Color(0,0,255))

		if a then
			return TraceData
		end

		--[[
		if Debug then
		print("angle: " .. angle .. " localang: " .. tostring(localang))
		print("height: " .. height)
		print("dist: " .. dist)
		print("(abs)planedist: " .. math.abs(ClippingPlaneHeight) .. " (abs)userheight: " .. math.abs(self:EyePos().z))
		end]]

		return Trace
	else
		if a then
			return oldUtilTrace(self, nil)
		end
		return oldEyeTrace(self)
	end
end

-- CALCULATE THE MOVEMENT

function CalculateRTSMovement(Ply, MoveData)
	if CLIENT then Ply = LocalPlayer() end
	if table.HasValue(RTSMovementPlayers, Ply) or (CLIENT && LocalPlayer():GetRTSViewState()) then

		local Velocity = MoveData:GetVelocity()
		local Position = MoveData:GetOrigin()
		local Speed = 10
		Velocity = Vector(0, 0, 0)
		if MoveData:KeyDown(IN_SPEED) then Speed = 30 end
		
		if MoveData:KeyDown(IN_WALK) then

			if MoveData:KeyDown(IN_FORWARD) then
				if CLIENT then
					Ply:SetRTSPlaneHeight(Ply:GetRTSPlaneHeight() + Speed/6)
					net.Start("SyncRTSPlaneHeight")
					net.WriteFloat(Ply:GetRTSPlaneHeight())
					net.SendToServer()
				end
			end
			if MoveData:KeyDown(IN_BACK) then
				if CLIENT then
					Ply:SetRTSPlaneHeight(Ply:GetRTSPlaneHeight() - Speed/6)
					net.Start("SyncRTSPlaneHeight")
					net.WriteFloat(Ply:GetRTSPlaneHeight())
					net.SendToServer()
				end
			end

			if MoveData:KeyDown(IN_MOVELEFT) then
				if Ply:GetRTSViewAngle() == nil then Ply:SetRTSViewAngle(0) end
				Ply:SetRTSViewAngle(Ply:GetRTSViewAngle() + (math.ceil(RealTime()) - RealTimeNow)*45)
			end

			if MoveData:KeyDown(IN_MOVERIGHT) then
				if Ply:GetRTSViewAngle() == nil then Ply:SetRTSViewAngle(0) end
				Ply:SetRTSViewAngle(Ply:GetRTSViewAngle() - (math.ceil(RealTime()) - RealTimeNow)*45)
			end

		else

			if MoveData:KeyDown(IN_FORWARD) then 
				local v1 = Vector(Speed, 0, 0)
				v1:Rotate(Angle(0,Ply:GetRTSViewAngle(),0))
				Velocity = v1
			end
			if MoveData:KeyDown(IN_BACK) then 
				local v1 = Vector(-Speed, 0, 0)
				v1:Rotate(Angle(0,Ply:GetRTSViewAngle(),0))
				Velocity = v1
			end
			if MoveData:KeyDown(IN_MOVELEFT) then 
				local v1 = Vector(0, Speed, 0)
				v1:Rotate(Angle(0,Ply:GetRTSViewAngle(),0))
				Velocity = v1
			end
			if MoveData:KeyDown(IN_MOVERIGHT) then
				local v1 = Vector(0, -Speed, 0)
				v1:Rotate(Angle(0,Ply:GetRTSViewAngle(),0))
				Velocity = v1
			end
			if MoveData:KeyDown(IN_DUCK) then
				Velocity = Vector(0, 0, -Speed)
			end
			if MoveData:KeyDown(IN_JUMP) then
				Velocity = Vector(0, 0, Speed)
			end

		end

		RealTimeNow = math.ceil(RealTime())
		MoveData:SetOrigin(Position + Velocity)
		MoveData:SetVelocity(Velocity)
		return true
	end
end

if SERVER then
	AddCSLuaFile()
	util.PrecacheModel("models/tools/axis/axis.mdl")
	-- CHANGE MOVEMENT'S STATE

	util.AddNetworkString("EnableRTSMovement")
	util.AddNetworkString("DisableRTSMovement")
	util.AddNetworkString("ChangeRTSViewState")
	util.AddNetworkString("SyncRTSPlaneHeight")

	net.Receive("EnableRTSMovement", function(Ln, Ply)
		table.insert(RTSMovementPlayers, Ply)
	end)

	net.Receive("DisableRTSMovement", function(Ln, Ply)
		GlobalRTSAngle = 45
		table.RemoveByValue(RTSMovementPlayers, Ply)
	end)

	net.Receive("ChangeRTSViewState", function(ln, ply)
		local state = net.ReadBool()
		ply:SetRTSViewState(state)
	end)

	net.Receive("SyncRTSPlaneHeight", function(ln, ply)
		local newval = net.ReadFloat()
		ply:SetRTSPlaneHeight(newval)
	end)

	-- MAKE CROSSHAIR VISIBLE AT ALL TIMES

	util.AddNetworkString("AddCrosshairToPVS")

	hook.Add("SetupPlayerVisibility", "AlwaysDrawRTSCrosshairPVS", function(pPlayer, pViewEntity)

		--[[
		print("consider player: " .. pPlayer:Name() .. ".")
		print("player rts state: " .. tostring(pPlayer:GetRTSViewState()) .. ".")
		]]

		if pPlayer:GetRTSViewState() then
			local xhairLoc = pPlayer:GetEyeTrace().HitPos

			if xhairLoc != nil then
				AddOriginToPVS(xhairLoc)
--				print("added " .. tostring(xhairLoc) .. " to pvs.")
			end
		end

	end)

	-- SYNCHRONIZE VIEW ANGLE WHEN ROTATING
	
	print("[RTSView] Serverside loaded!")

else -- CLIENTSIDE CLIENTSIDE CLIENTSIDE
-- CLIENTSIDE CLIENTSIDE CLIENTSIDE

	-- DETECT THE COMMAND

	function DetectCommand(Ply, Text, TeamChat, IsDead)
		if Ply == LocalPlayer() && !IsDead then
			if Text == "/rtsview" then
				return true
			else
				return false
			end
		end
	end

	-- CALCULATE THE VIEW

	function CalculateRTSView(Ply, Origin, Angles, FOV, ZNear, ZFar)
		local View = {}
		local modifier = 1
		View.origin = Ply:EyePos() --+ Vector(-150*modifier,-150*modifier,200*modifier)
		LocalPlayer():DrawViewModel(false)
		View.angles = Angle(45,LocalPlayer():GetRTSViewAngle(),0)
		View.fov = 45
		View.drawviewer = false
--		View.ortho = true
--		View.orthotop = -10

		return View
	end

	-- ALIGN CROSSHAIRS

	local GUIPanel = nil

	function StartDrawingPanel()
		if Main ~= nil then vgui.Remove(Main) end
		local Main = vgui.Create("DPanel")
		Main:SetSize(ScrW(), ScrH())
		Main:SetPos(0,0)
		Main:SetWorldClicker(true)
		Main:SetPaintBackground(false)
		gui.EnableScreenClicker(true)
		GUIPanel = Main
	end

	-- SET THE VIEW'S STATE

	function SendChangeRTSState(state)
		net.Start("ChangeRTSViewState")
		net.WriteBool(state)
		net.SendToServer()
	end

	function EnableRTSView()
		if Debug then print("[RTSView] Enabled!") end
		LocalPlayer():SetRTSPlaneHeight(-LocalPlayer():GetPos().z)
		LocalPlayer():DrawViewModel(false)
		LocalPlayer():SetRTSViewState(true)
		net.Start("EnableRTSMovement")
		net.SendToServer()
		net.Start("SyncRTSPlaneHeight")
		net.WriteFloat(LocalPlayer():GetRTSPlaneHeight())
		net.SendToServer()
		LocalPlayer():SetEyeAngles(Angle(45,45,0))
		hook.Add("CalcView", "CalcViewRTS", CalculateRTSView)
		SendChangeRTSState(true)
--		StartDrawingPanel()
	end

	function DisableRTSView()
		if Debug then print("[RTSView] Disabled!") end
		GlobalRTSAngle = 45
		LocalPlayer():DrawViewModel(true)
		LocalPlayer():SetRTSViewState(false)
		net.Start("DisableRTSMovement")
		net.SendToServer()
		hook.Remove("CalcView", "CalcViewRTS")
		SendChangeRTSState(false)
--		GUIPanel:Remove()
	end

	-- LISTEN FOR THE COMMAND

	hook.Add("OnPlayerChat", "ListenForRTSViewCommand", function(Ply, Text, TeamChat, IsDead)
		if DetectCommand(Ply, Text, TeamChat, IsDead) then
			if !Ply:GetRTSViewState() then
				EnableRTSView()
				return false
			else
				DisableRTSView()
				return false
			end
		end
	end)

	-- DRAW CUSTOM CROSSHAIR

CrosshairModel = ClientsideModel( "models/tools/axis/axis.mdl", RENDERGROUP_OPAQUE )

	hook.Add("PostDrawTranslucentRenderables", "DrawRTSCrosshair", function()
		if LocalPlayer():GetRTSViewState() then
			if ( bSkybox ) then return end
		
		 --[[
			TraceData = {
				start = LocalPlayer():EyePos(),
				endpos = LocalPlayer():EyeAngles():Forward() * LocalPlayer():EyePos() * 60,
				mask = MASK_PLAYERSOLID_BRUSHONLY,
			}]]
		--[[TraceData = {
				start = LocalPlayer():GetEyeTrace().Normal*(-LocalPlayer():EyePos().z - ClippingPlaneHeight+10),
				endpos = LocalPlayer():GetEyeTrace().Normal*(-LocalPlayer():EyePos().z - ClippingPlaneHeight+10) * 63400
			}]]


--			local vecToPlane = math.abs(-LocalPlayer():EyePos().z - ClippingPlaneHeight)
--			local v1 = ClippingPlaneHeight * trVec

			--[[
			local TraceData = {
				start = EyePos(),
				endpos = EyePos() + trVec * dist
			}]] -- This gives the crosshair exactly on the clipping plane

			--[[
			print("eyePos: " .. tostring(EyePos()))
			print("eyePos * dist: " .. tostring(EyePos() + trVec * dist))
			debugoverlay.Line(EyePos(), EyePos() + trVec * dist, 1, Color(255,0,0), false)
			]]

--[[			if Debug then
				print("Start: " .. tostring(TraceData.start))
				print("End: " .. tostring(TraceData.endpos))
				print("Distance to plane: " .. " (PLY: " .. -LocalPlayer():EyePos().z .. "), (CLIP: " .. ClippingPlaneHeight .. "): " .. tostring(-LocalPlayer():EyePos().z - ClippingPlaneHeight))
			end]]
--[[
			if LocalPlayer():EyePos().z < ClippingPlaneHeight then
				Trace = LocalPlayer():GetEyeTrace()
			end
]]
			--if Debug then print("Trace Hit: " .. tostring(Trace.Entity)) end

			Trace = LocalPlayer():GetEyeTrace()

			CrosshairModel:SetModelScale((LocalPlayer():EyePos():Distance(Trace.HitPos))/250)
--			print("hit " .. tostring(Trace.HitPos))
			CrosshairModel:SetMaterial("models/debug/debugwhite")
			CrosshairModel:SetColor(Color(0,255,0,255))

			local ModelTable = {
				model = "models/tools/axis/axis.mdl",
				pos = Trace.HitPos,
				Angle(0,0,45)
			}

			render.SetAmbientLight(255,255,255)
			render.SetColorMaterialIgnoreZ()
			render.Model(ModelTable, CrosshairModel)

		end
	end)

	local hasDrawnWorld = false
  	cssEnt = ClientsideModel("models/error/error.mdl", RENDERGROUP_OTHER)

	-- old: SetupWorldFog
    hook.Add("NeedsDepthPass", "ClipRTSWorldPush", function()
		if LocalPlayer():GetRTSViewState() then
            hasDrawnWorld = false
            render.EnableClipping(true)
--			print(ClippingPlaneHeight)
            render.PushCustomClipPlane(Vector(0,0,-1), LocalPlayer():GetRTSPlaneHeight() )
			render.GetResolvedFullFrameDepth()
			render.OverrideDepthEnable(true, true)				
			return true
		end
	end)

	hook.Add("PostDrawOpaqueRenderables", "RenderSecondRTSWorld", function()
		if LocalPlayer():GetRTSViewState() then
			local map = bsp2.GetModelInfo()
			print(map)
			local scale = 1
			local m = Matrix()

			render.PushFilterMag(TEXFILTER.ANISOTROPIC)
			render.PushFilterMin(TEXFILTER.ANISOTROPIC)
			render.SetLightingMode(0)
			
			cam.PushModelMatrix(m)
				for k, v in ipairs(map.meshes) do
					render.SetMaterial(map.materials[k])
					v:Draw()
				end
				for k, v in ipairs(map.entities) do
					v:DrawModel()
				end
				for k,v in ipairs(player.GetAll()) do
					cssEnt:SetModel(v:GetModel())
					cssEnt:SetPos(v:GetPos())
					cssEnt:SetupBones()
					cssEnt:DrawModel()
				end
		end
	end)

    hook.Add("PreDrawEffects", "ClipRTSWorldPop", function(bDepth, bSky)
		if LocalPlayer():GetRTSViewState() then
            if (hasDrawnWorld) then return end

			-- End new world render
			cam.PopModelMatrix()
			render.PopFilterMin()
			render.PopFilterMag()

			-- And then get rid of the plane.
            render.PopCustomClipPlane() 
            render.EnableClipping(false)
			render.OverrideDepthEnable(false, false)
            --print("end")
            hasDrawnWorld = true
		end
    end)
	print("[RTSView] Clientside loaded!")

end

hook.Add("Move", "CalculateRTSMovement", CalculateRTSMovement)
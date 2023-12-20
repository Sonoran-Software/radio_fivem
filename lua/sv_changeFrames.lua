function checkFramePermissions(player)
	local allowedFrames = {}
	-- Check if the permission mode is 'ace' and departments are defined
	if Config.frames.permissionMode == 'ace' and Config.frames.departments then
		for _, department in pairs(Config.frames.departments) do
			-- Check if department has 'ace' permissions defined
			if department.permissions and department.permissions.ace then
				for _, acePermission in ipairs(department.permissions.ace) do
					if IsPlayerAceAllowed(player, acePermission) then
						-- Add allowed frames for this department to the list
						for _, frame in ipairs(department.allowedFrames or {}) do
							allowedFrames[frame] = true
						end
					end
				end
			end
		end
	elseif Config.frames.permissionMode == 'qbcore' and Config.frames.departments then
		local QBCore = exports['qb-core']:GetCoreObject()
		local QBPlayer = QBCore.Functions.GetPlayer(player)
		for _, department in pairs(Config.frames.departments) do
			-- Check if department has 'qbcore' permissions defined
			if department.permissions and department.permissions.jobs then
				for _, qbPermission in ipairs(department.permissions.jobs) do
					if QBPlayer.PlayerData.job.name == qbPermission then
						-- Add allowed frames for this department to the list
						for _, frame in ipairs(department.allowedFrames or {}) do
							allowedFrames[frame] = true
						end
					end
				end
			end
		end
	elseif Config.frames.permissionMode == 'esx' and Config.frames.departments then
		local ESX = exports['es_extended']:getSharedObject()
		local ESXPlayer = ESX.GetPlayerFromId(player)
		for _, department in pairs(Config.frames.departments) do
			-- Check if department has 'esx' permissions defined
			if department.permissions and department.permissions.jobs then
				for _, esxPermission in ipairs(department.permissions.jobs) do
					if ESXPlayer.job.name == esxPermission then
						-- Add allowed frames for this department to the list
						for _, frame in ipairs(department.allowedFrames or {}) do
							allowedFrames[frame] = true
						end
					end
				end
			end
		end
	elseif Config.frames.permissionMode == 'none' and Config.frames.departments then
		-- Add all frames to the list
		for _, department in pairs(Config.frames.departments) do
			for _, frame in ipairs(department.allowedFrames or {}) do
				allowedFrames[frame] = true
			end
		end
	end
	return allowedFrames
end
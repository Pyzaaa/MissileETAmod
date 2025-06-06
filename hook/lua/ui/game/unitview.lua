local oldUpdateWindow = UpdateWindow

-- Override statFuncs[5], that might break something
statFuncs[5] = function(info)
    if info.tacticalSiloMaxStorageCount > 0 or info.nukeSiloMaxStorageCount > 0 then
        if info.userUnit and info.userUnit:IsInCategory('VERIFYMISSILEUI') then
            local curEnh = EnhancementCommon.GetEnhancements(info.userUnit:GetEntityId())
            --this part is for UEF missile ACU
            if curEnh then
                if curEnh.Back == 'TacticalMissile' then
                    return string.format('%d / %d', info.tacticalSiloStorageCount, info.tacticalSiloMaxStorageCount), 'tactical'
                elseif curEnh.Back == 'TacticalNukeMissile' then
                    local etaString = "Missile ETA UI"
                    CalculateETA(info)
                    if info.missileBuildProgress and info.missileBuildETA then
                        etaString = string.format(" (%.0f%%, ETA %ds)", info.missileBuildProgress * 100, math.ceil(info.missileBuildETA))
                    end
                    return string.format('%d / %d%s', info.nukeSiloStorageCount, info.nukeSiloMaxStorageCount, etaString), 'strategic'
                else
                    return false
                end
            else
                return false
            end
        end
        if info.nukeSiloMaxStorageCount > 0 then
            --this is for the SML
            local etaString = "Missile ETA UI"
            CalculateETA(info)
            if info.missileBuildProgress and info.missileBuildETA then
                etaString = string.format(" (%.0f%%, ETA %ds)", info.missileBuildProgress * 100, math.ceil(info.missileBuildETA))
            end
            return string.format('%d / %d%s', info.nukeSiloStorageCount, info.nukeSiloMaxStorageCount, etaString), 'strategic'
        else
            --this is for SMD and TML
            local etaString = "Missile ETA UI"
            CalculateETA(info)
            if info.missileBuildProgress and info.missileBuildETA then
                etaString = string.format(" (%.0f%%, ETA %ds)", info.missileBuildProgress * 100, math.ceil(info.missileBuildETA))
            end
            return string.format('%d / %d%s', info.tacticalSiloStorageCount, info.tacticalSiloMaxStorageCount, etaString), 'tactical'
        end
        -- no idea how to fix it lol
    elseif info.userUnit and table.getn(GetAttachedUnitsList({info.userUnit})) > 0 then
        return string.format('%d', table.getn(GetAttachedUnitsList({info.userUnit}))), 'attached'
    else
        return false
    end
end

function CalculateETA(info)
    if not info or not info.blueprintId then
        --LOG("Missile ETA UI: No info or blueprintId")
        return
    end

    local bpId = info.blueprintId
    local bp = __blueprints[bpId]

    if not bp or not bp.Weapon then
        --LOG("Missile ETA UI: No valid blueprint or weapon found")
        return
    end

    local missileBuildTime = nil

    -- Look through weapons to find the missile

    local function HasCategory(bp, category)
        if bp.Categories then
            for _, cat in bp.Categories do
                if cat == category then
                    return true
                end
            end
        end
        return false
    end

    for _, weapon in bp.Weapon do
        --LOG(repr(weapon))
        if weapon.WeaponCategory == 'Missile' and weapon.DamageType == "Nuke" or weapon.WeaponCategory == 'Defense' then
            -- Find the actual missile unit blueprint
            local missileBpId = weapon.ProjectileId or weapon.BlueprintId or weapon.MissileId

            if missileBpId and __blueprints[missileBpId] then
                local missileBp = __blueprints[missileBpId]
                if missileBp.Economy and missileBp.Economy.BuildTime then
                    missileBuildTime = missileBp.Economy.BuildTime
                    --LOG("Missile ETA UI: Found missile build time: " .. missileBuildTime)
                    break
                end
            end
        
        elseif weapon.WeaponCategory == 'Missile' and not HasCategory(bp, "MOBILE") then
            -- Find the actual missile unit blueprint
            local missileBpId = weapon.ProjectileId or weapon.BlueprintId or weapon.MissileId

            if missileBpId and __blueprints[missileBpId] then
                local missileBp = __blueprints[missileBpId]
                if missileBp.Economy and missileBp.Economy.BuildTime then
                    missileBuildTime = missileBp.Economy.BuildTime
                    --LOG("Missile ETA UI: Found missile build time: " .. missileBuildTime)
                    break
                end
            end
            
        end
    end

    if not missileBuildTime then
        LOG("Missile ETA UI: Could not determine missile build time")
        return
    end

    local progress = info.workProgress or 0
    local buildRate = bp.Economy.BuildRate or 1

    -- Build progress is [0..1]
    local elapsedTime = missileBuildTime * progress
    local eta = ((missileBuildTime - elapsedTime) / buildRate)

    info.missileBuildProgress = progress
    info.missileBuildETA = eta

    --LOG(string.format("Missile ETA UI: Calculation successful - progress: %.2f, ETA: %.2fs", progress, eta))
end


function UpdateWindow(info)
    oldUpdateWindow(info)
end

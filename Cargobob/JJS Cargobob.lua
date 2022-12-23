if menu.get_trust_flags() ~= (1 << 2) then
    menu.notify("JJS Cargobob requires \"Natives\" Trust flag", "Trust Error", nil, 0x0000FF)
    menu.exit()
end

local function request_model(_hash)
    if not streaming.has_model_loaded(_hash) then
        streaming.request_model(_hash)
        while (not streaming.has_model_loaded(_hash)) do
            system.yield(10)
        end
    end
end

local function request_control(_ent)
    local attempts = 75
    if not network.has_control_of_entity(_ent) then
        network.request_control_of_entity(_ent)
        while (not network.has_control_of_entity(_ent)) and (attempts > 0) do
            system.yield(0)
            attempts = attempts-1
        end
    end
end

local vehicle_hash = gameplay.get_hash_key("cargobob")
local ped_hash = 988062523

local blips = {}
local heli_ped
local heli_veh

local is_heli_active = false
local heli_rappeldown2 = false

local function clear_all_noyield(delay)
    if delay and type(delay) == "number" then
        system.yield(delay)
    end

    for k,v in pairs(blips) do
        ui.remove_blip(v)
    end

    print("Deleting",heli_ped)
    entity.delete_entity(heli_ped or 0)

    entity.delete_entity(heli_veh or 0)

    is_heli_active = false
    
    heli_ped = 0
    heli_veh = 0
end

local function clear_all(delay,peds,vehicle,reset)
    if delay and type(delay) == "number" then
        system.yield(delay)
    end

    for k,v in pairs(blips) do
        repeat
            ui.remove_blip(v)
            system.yield(0)
        until native.call(0xE41CA53051197A27, v):__tointeger() == 0
        blips = {}
    end

    local attempts = 0

    if peds and heli_ped ~= nil then
        request_control(heli_ped)
        repeat
            entity.delete_entity(heli_ped)
            system.yield(0)
            attempts = attempts+1
        until not entity.is_an_entity(heli_ped) or attempts > 300
    end

    local attempts = 0

    if vehicle and heli_veh ~= nil then
        request_control(heli_veh)
        repeat
            entity.delete_entity(heli_veh)
            attempts = attempts+1
            system.yield(0)
        until not entity.is_an_entity(heli_veh) or attempts > 300
        heli_veh = 0
    end

    if vehicle and peds and (reset or true) then
        is_heli_active = false
    end
end

local ground_check = {900}

repeat
    ground_check[#ground_check+1] = ground_check[#ground_check] - 25
until ground_check[#ground_check] < 26

local function get_ground(pos)
    for k,v in ipairs(ground_check) do
        native.call(0x07503F7948F491A7, v3(pos.x, pos.y, v))
        system.yield(0)
    end

    system.yield(1500)

    for k,v in ipairs(ground_check) do
        local destv3_check = v3(pos.x, pos.y, v)
        local groundz = native.ByteBuffer8()
        native.call(0xC906A7DAB05C8D2B, destv3_check, groundz, false, false)
        if groundz:__tonumber() ~= 0 then
            return groundz:__tonumber()
        end
        system.yield(0)
    end
    return 50
end

local function notify(text,title,time,color)
    if is_heli_active then
        menu.notify(text,title,time,color)
    end
end

function front_of_pos(_pos,_rot,_dist)
    _rot:transformRotToDir()
    _rot = _rot * _dist
    _pos = _pos + _rot
    return _pos
end

function vector_to_heading(_target,_start)
    return math.atan((_target.x - _start.x), (_target.y - _start.y)) * -180 / math.pi
end


local main_menu = menu.add_feature("#FFFFC64D#J#FFFFD375#J#FFFFE1A1#S #FFFFF8EB#Cargobob", "parent", 0)

local magnet_mode = menu.add_feature("Use Magnet?","toggle",main_menu.id)
magnet_mode.hint = "Use a magnet instead of a hook."

local spawn_cargo = menu.add_feature("Spawn Cargobob","action",main_menu.id, function()
    is_heli_active = true
    local local_player = player.player_id()
    local player_pos = player.get_player_coords(local_player)
    local player_ped = player.get_player_ped(local_player)
    local player_heading = player.get_player_heading(local_player)

    local player_veh = ped.get_vehicle_ped_is_using(player_ped)
    local veh_height = native.call(0x5A504562485944DD, player_veh, player_pos, true, false):__tonumber()
    local veh_pos = entity.get_entity_coords(player_veh)
    local veh_heading = entity.get_entity_heading(player_veh)

    local spawn_pos = player_pos+v3(0,0,35)

    local pickup_pos = front_of_pos(veh_pos, v3(0,0,veh_heading), -1)

    request_model(vehicle_hash)
    heli_veh = vehicle.create_vehicle(vehicle_hash, spawn_pos, veh_heading, true, false)

    vehicle.set_heli_blades_full_speed(heli_veh)
    native.call(0x2311DD7159F00582, heli_veh, true)
    native.call(0xDBC631F109350B8C, heli_veh, true)

    vehicle.set_vehicle_mod_kit_type(heli_veh, 0)
    vehicle.set_vehicle_colors(heli_veh, 12, 141)
    vehicle.set_vehicle_extra_colors(heli_veh, 62, 0)
    vehicle.set_vehicle_window_tint(heli_veh, 1)

    if entity.is_an_entity(heli_veh) then
        blips.heli_veh = ui.add_blip_for_entity(heli_veh)
        ui.set_blip_sprite(blips.heli_veh, 422)
        ui.set_blip_colour(blips.heli_veh, 2)

        native.call(0xF9113A30DE5C6670, "STRING")
        native.call(0x6C188BE134E074AA, "Cargobob")
        native.call(0xBC38B49BCB83BC9B, blips.heli_veh)
    end


    request_model(ped_hash)
    heli_ped = ped.create_ped(0, ped_hash, spawn_pos, 0, true, false)
    ped.set_ped_into_vehicle(heli_ped, heli_veh, -1)
    native.call(0x9F8AA94D6D97DBF4, heli_ped, true)
    native.call(0x1913FE4CBF41C463, heli_ped, 255, true)
    native.call(0x1913FE4CBF41C463, heli_ped, 251, true)

    native.call(0x1F4ED342ACEFE62D, heli_ped, true, true)
    native.call(0x1F4ED342ACEFE62D, heli_veh, true, true)

    native.call(0xDAD029E187A2BEB4, heli_ped, heli_veh, 0, 0, pickup_pos.x, pickup_pos.y, pickup_pos.z+veh_height+2, 4, 70.0, 3.0, veh_heading, 100, 1, 400.0, 64+4096)
    native.call(0x7BEB0C7A235F6F3B, heli_veh, 0)
    native.call(0x9A665550F8DA349B, heli_veh, true)

    if magnet_mode.on then
        native.call(0xE301BD63E9E13CF0, player_veh, heli_veh)
        native.call(0xBCBFCD9D1DAC19E2, heli_veh, 0.0)
        native.call(0xED8286F71A819BAA, heli_veh, 0.0)

        repeat
            local curr_heli_pos = entity.get_entity_coords(heli_veh)
            local curr_veh_pos = entity.get_entity_coords(player_veh)
            local dist = native.call(0xB7A628320EFF8E47, curr_heli_pos, curr_veh_pos):__tonumber()
            system.yield(0)
            print(dist)
        until dist < 45 or not is_heli_active
    else
        repeat
            system.yield(0)
        until native.call(0x873B82D42AC2B9E5, heli_veh):__tointeger() == player_veh
    end
    print("Picked up vehicle")

    local wp = ui.get_waypoint_coord()
    local wpz = get_ground(wp)

    local wp3 = v3(wp.x, wp.y, wpz+100)

    notify("Flying to:\nX: "..wp3.x.." Y: "..wp3.y.." Z: "..wp3.z,"Flying to Dest",nil,0x00AAFF)

    blips.dest = ui.add_blip_for_coord(wp3)
    ui.set_blip_sprite(blips.dest, 58)
    ui.set_blip_colour(blips.dest, 5)

    native.call(0xF9113A30DE5C6670, "STRING")
    native.call(0x6C188BE134E074AA, "Cargobob Destination")
    native.call(0xBC38B49BCB83BC9B, blips.dest)

    print("Flying to dest")
    request_control(heli_veh)
    request_control(heli_ped)
    native.call(0xE1EF3C1216AFF2CD, heli_ped)
    native.call(0xDAD029E187A2BEB4, heli_ped, heli_veh, 0, 0, wp3.x, wp3.y, wp3.z, 4, 50.0, 50.0, -1, 100, 30, 200.0, 0)

    while true do
        local heli_pos_live = entity.get_entity_coords(heli_veh)

        local dist_x = math.abs(heli_pos_live.x - wp3.x)
        local dist_y = math.abs(heli_pos_live.y - wp3.y)
        local dist_z = math.abs(heli_pos_live.z - wp3.z)

        local hori_dist = dist_x+dist_y

        if hori_dist < 300 or not is_heli_active then
            print("Slowing Down")
            native.call(0x5C9B84BD7D31D908, heli_ped, 20)
            break
        end
        system.yield(0)
    end

    print("Landing to dest")
    request_control(heli_veh)
    request_control(heli_ped)
    native.call(0xE1EF3C1216AFF2CD, heli_ped)
    native.call(0xDAD029E187A2BEB4, heli_ped, heli_veh, 0, 0, wp3.x, wp3.y, wp3.z, 4, 20.0, 10.0, -1, 50, 30, 75.0, 0)

    while true do
        local heli_pos_live = entity.get_entity_coords(heli_veh)

        local dist_x = math.abs(heli_pos_live.x - wp3.x)
        local dist_y = math.abs(heli_pos_live.y - wp3.y)
        local dist_z = math.abs(heli_pos_live.z - wp3.z)

        local hori_dist = dist_x+dist_y

        if hori_dist < 15 or not is_heli_active then
            print("Landing")
            break
        end
        system.yield(0)
    end

    local curr_heli_heading = entity.get_entity_heading(heli_veh)

    native.call(0xDAD029E187A2BEB4, heli_ped, heli_veh, 0, 0, wp3.x, wp3.y, wp3.z-85, 4, 50.0, 50.0, curr_heli_heading, 100, 5, 400.0, 1)

    repeat
        local heli_pos_live = entity.get_entity_coords(heli_veh)

        local dist_x = math.abs(heli_pos_live.x - wp3.x)
        local dist_y = math.abs(heli_pos_live.y - wp3.y)
        local dist_z = math.abs(heli_pos_live.z - (wp3.z-85))

        local full_dist = dist_x+dist_y+dist_z
        system.yield(0)
    until (full_dist < 30 and entity.get_entity_speed(heli_veh) < 8) or not is_heli_active

    system.yield(2000)

    if magnet_mode.on then
        native.call(0x9A665550F8DA349B, heli_veh, false)
    else
        native.call(0x0E21D3DF1051399D, player_veh, heli_veh)
    end

    system.yield(3000)

    native.call(0xDE564951F95E09ED, heli_veh, true, true)
    native.call(0xDE564951F95E09ED, heli_ped, true, true)

    system.yield(2000)

    notify("Thanks you for using JJS-Airtaxi!","Thanks You",nil,0xc203fc)
    clear_all(nil,true,true)
    is_heli_active = false
end)
spawn_cargo.hint = "Spawn the cargobob to pick up the player's current vehicle, then brings it to waypoint."

local clean_heli = menu.add_feature("Clear All","action",main_menu.id,function()
    clear_all(nil,true,true,false)
end)
clean_heli.hint = "Clean up heli + pilot"

event.add_event_listener("exit", clear_all_noyield)
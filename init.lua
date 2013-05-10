-- meseor 0.1.0 by paramat.
-- License WTFPL, see license.txt.

-- Parameters.

local IMPACT = true -- (true / false) -- Enable / disable impacts.
local DAMAGE = true -- Enable / disable player damage loop.
local DAMMAX = 20 -- 20 -- Maximum damage. 20 = direct hit is fatal.
local MSRINT = 181 --  -- Meseor abm interval.
local MSRCHA = 100000 --  -- Meseor 1/x chance per node.
local RADMIN = 6 -- 6 -- Minimum crater radius.
local RADMAX = 32 -- 32 -- Maximum crater radius.
local STOCHA = 5 -- 5 -- 1/x chance of stone boulders instead of gravel.
local DEBUG = true

local XMIN = -16384 -- Impact area dimensions. Impacts only inside this area.
local XMAX = 16384
local ZMIN = -16384
local ZMAX = 16384

local SAXMIN = 30000 -- Safe area dimensions. No impacts inside this area.
local SAXMAX = 30000 -- When overlapping impact area, the safe area overrides.
local SAZMIN = 30000
local SAZMAX = 30000

-- Stuff.

meseor = {}

-- Meseor abm.

if IMPACT then
	minetest.register_abm({
		nodenames = {
			"default:dirt",
			"default:dirt_with_grass",
			"default:desert_sand",
			"default:sand",
		},    
		interval = MSRINT,	
		chance = MSRCHA,
		action = function(pos, node, _, _)
			local env = minetest.env
			local x = pos.x
			local y = pos.y
			local z = pos.z
			-- If in safe zone or not in impact zone then abort.
			if (x > SAXMIN and x < SAXMAX and z > SAZMIN and z < SAZMAX)
			or not (x > XMIN and x < XMAX and z > ZMIN and z < ZMAX) then
				return
			end
			-- Find surface above, abort if underwater or no surface found.
			local surfy = false
			for j = 1, 8 do
				local nodename = env:get_node({x=x,y=y+j,z=z}).name
				if nodename == "default:water_source" or nodename == "default:water_flowing" then
					return
				elseif nodename == "air" then
					surfy = y+j-1
					break
				end
			end
			if not surfy then
				return
			end
			-- Check pos open to sky.
			for j = 1, 160 do
				local nodename = env:get_node({x=x,y=surfy+j,z=z}).name
				if nodename ~= "air" and nodename ~= "ignore" then
					return
				end
			end
			-- Random radius.
			local conrad = math.random(RADMIN, RADMAX)
			local rimrad = conrad * 2.2
			-- Check enough depth.
			for j = -conrad - 1, -1 do
				local nodename = env:get_node({x=x,y=surfy+j,z=z}).name
				if nodename == "air" or nodename == "ignore" then
					return
				end
			end
			-- Excavate cone and count excavated nodes.
			local exsto = 0
			local exdsto = 0
			local exdirt = 0
			local exdsan = 0
			local exsan = 0
			local extree = 0
			for j = 0, conrad * 2 do
				for i = -j, j do
				for k = -j, j do
					if i ^ 2 + k ^ 2 <= j ^ 2 then
						local nodename = env:get_node({x=x+i,y=surfy-conrad+j,z=z+k}).name
						if nodename == "default:stone" then
							exsto = exsto + 1
						elseif nodename == "default:desert_stone" then
							exdsto = exdsto + 1
						elseif nodename == "default:dirt" or nodename == "default:dirt_with_grass" then
							exdirt = exdirt + 1
						elseif nodename == "default:desert_sand" then
							exdsan = exdsan + 1
						elseif nodename == "default:sand" then
							exsan = exsan + 1
						elseif nodename == "default:tree" then
							extree = extree + 1
						end
						if nodename ~= "air" then
							env:remove_node({x=x+i,y=surfy-conrad+j,z=z+k})
						end
					end
				end
				end
			end
			-- Calculate proportions of ejecta.
			local extot = exsto + exdsto + exdirt + exdsan + exsan + extree
			local pexsto = exsto / extot
			local pexdsto = exdsto / extot
			local pexdirt = exdirt / extot
			local pexdsan = exdsan / extot
			local pexsan = exsan / extot
			local pextree = extree / extot
			-- Print to terminal.
			if DEBUG then
				print ("[meseor] Radius "..conrad.." node ("..x.." "..surfy.." "..z..")")
				print ("[meseor] exsto "..exsto.." exdsto "..exdsto.." exdirt "..exdirt.." exdsan "..exdsan.." exsan "..exsan.." extree "..extree)
				print ("[meseor] extot "..extot)
				print ("[meseor] pexsto "..pexsto.." pexdsto "..pexdsto.." pexdirt "..pexdirt.." pexdsan "..pexdsan.." pexsan "..pexsan.." pextree "..pextree)
			end
			-- Add meseorite.
			env:add_node({x=x,y=surfy-conrad,z=z},{name="default:mese"})
			-- Add ejecta.
			local addtot = 0
			for rep = 1, 32 do
				for i = -rimrad, rimrad do
				for k = -rimrad, rimrad do
					local rad = (i ^ 2 + k ^ 2) ^ 0.5
					if rad <= rimrad and math.random() > math.abs(rad - conrad * 1.1) / (conrad * 1.1) and addtot < extot then
						-- Find ground.
						local groundy = false
						for j = conrad - 1, -160, -1 do
							local nodename = env:get_node({x=x+i,y=surfy+j,z=z+k}).name
							if nodename == "default:leaves" or nodename == "default:jungleleaves"
							or nodename == "default:papyrus" or nodename == "default:dry_shrub"
							or nodename == "default:grass_1" or nodename == "default:grass_2"
							or nodename == "default:grass_3" or nodename == "default:grass_4"
							or nodename == "default:grass_5" or nodename == "default:apple"
							or nodename == "default:junglegrass" then
								env:remove_node({x=x+i,y=surfy+j,z=z+k})
							elseif nodename ~= "air" and nodename ~= "ignore"
							and nodename ~= "default:water_source" and nodename ~= "default:water_flowing" then
								groundy = surfy+j
								break
							end
						end
						if groundy then
							local x = x + i
							local y = groundy + 1
							local z = z + k
							if math.random() < pextree then
								env:add_node({x=x,y=y,z=z},{name="default:tree"})
							elseif math.random() < pexsan then
								env:add_node({x=x,y=y,z=z},{name="default:sand"})
							elseif math.random() < pexdsan then
								env:add_node({x=x,y=y,z=z},{name="default:desert_sand"})
							elseif math.random() < pexdirt then
								env:add_node({x=x,y=y,z=z},{name="default:dirt"})
							elseif math.random() < pexdsto then
								env:add_node({x=x,y=y,z=z},{name="default:desert_stone"})
							elseif math.random() < pexsto then
								if math.random(STOCHA) == 2 then
									env:add_node({x=x,y=y,z=z},{name="default:stone"})
								else
									env:add_node({x=x,y=y,z=z},{name="default:gravel"})
								end
							end
							addtot = addtot + 1
						end
					end
				end
				end
				if addtot == extot then break end
			end
			-- Play sound.
			minetest.sound_play("meseor", {gain = 1})
			-- Damage player if inside rimrad.
			if DAMAGE then
				for _,player in ipairs(minetest.get_connected_players()) do
					local plapos = player:getpos()
					local pladis = ((plapos.x - x) ^ 2 + (plapos.y - y) ^ 2 + (plapos.z - z) ^ 2) ^ 0.5
					local pladam = math.ceil((1 - pladis / rimrad) * DAMMAX)
					if pladam > 0 then
						player:set_hp(player:get_hp() - pladam)
					end
				end
			end
		end,
	})
end

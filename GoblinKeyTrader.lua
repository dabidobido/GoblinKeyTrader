_addon.name = 'Goblin Key Trader'
_addon.author = 'Dabidobido'
_addon.version = '2.1.0'
_addon.commands = {'gkt'}

require('logger')
require('tables')
local packets = require('packets')

trade_item_ids = {
	["SP Gobbie Key"] =  8973,
	["Dial Key #ANV"] = 9274,
	["Dial Key #FO"] = 9218,
}
number_of_items = T{}
loop_update = 0

windower.register_event('addon command', function(...)
	local args = {...}
	if args[1] == "trade" then
		trade()
	elseif args[1] == "stop" or args[1] == "s" then
		number_of_items = T{}
		notice("Stopping trades.")
	elseif args[1] == "help" then
		notice("//gkt trade: Trades keys to Goblin")
		notice("//gkt stop: Stops trading keys to Goblin")
	end
end)

function trade()
	local inventory = windower.ffxi.get_items(0)
	number_of_items = T{}
	for name, id in pairs(trade_item_ids) do
		for i = 1, inventory.max, 1 do
			if inventory[i] and inventory[i].id == id then
				if number_of_items[name] == nil then
					number_of_items[name] = inventory[i].count
				else
					number_of_items[name] = number_of_items[name] + inventory[i].count
				end
			end
		end
	end
	if number_of_items:length() > 0 then
		for name, number in pairs(number_of_items) do
			notice("Found " .. number .. " " .. name)
		end
		loop_update = os.clock()
	else
		notice("Didn't find any keys for Goblin")
	end
end

function update_loop()
	if number_of_items:length() > 0 then
		local time_now = os.clock()
		if not trading and time_now >= loop_update then
			local player = windower.ffxi.get_player()
			if player.status == 0 then
				local inventory = windower.ffxi.get_bag_info(0)
				if inventory.count == inventory.max then 
					number_of_items = {}
					notice("Inventory full")
				else
					local item_name = nil
					for name, number in pairs(number_of_items) do
						if number > 0 then
							trading = true
							windower.send_command('input /targetnpc;wait 0.1;input /item "' .. name .. '" <t>')
							notice(number .. " " .. name .. " left to trade.")
						end
						item_name = name
						break
					end
					if item_name ~= nil then 
						number_of_items[item_name] = number_of_items[item_name] - 1
						if number_of_items[item_name] == -1 then
							number_of_items[item_name] = nil
						end
					end
				end
			end
			loop_update = time_now + 3
		end
	end
end

function parse_incoming(id, original, modified, injected, blocked)
	if trading then
		if id == 0x032 or id == 0x034 then
			local data = packets.parse('incoming', original)
			local pkt = packets.new('outgoing', 0x05B)
			pkt['Target'] = data['NPC']
			pkt['Target Index'] = data['NPC Index']
			pkt['Option Index'] = 1
			pkt['_unknown1'] = 0
			pkt['Automated Message'] = true
			pkt['Zone'] = data['Zone']
			pkt['Menu ID'] = data['Menu ID']
			packets.inject(pkt)
			pkt['Option Index'] = 2
			packets.inject(pkt)
			pkt['Automated Message'] = false
			packets.inject(pkt)
			return true
		elseif id == 0x037 then
			return true
		elseif id == 0x02A then
			trading = false
			return false
		end
	end
end

windower.register_event("prerender", update_loop)
windower.register_event("incoming chunk", parse_incoming)
ESX             = nil

TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)

-- lib.versionCheck(repository) -- Version check

local playersInDealerships = {}
local Displays = {}

RegisterServerEvent("just_dealerships:playerEnteredDealership")
AddEventHandler("just_dealerships:playerEnteredDealership", function(dealership)
    table.insert(playersInDealerships,  {dealership = dealership, player = source})
end)

RegisterServerEvent("just_dealerships:playerLeftDealership")
AddEventHandler("just_dealerships:playerLeftDealership", function()
    for k, v in pairs(playersInDealerships) do
        if v.player == source then
            table.remove(playersInDealerships, k)
            break
        end
    end
end)

RegisterServerEvent("just_dealerships:updateDisplays")
AddEventHandler("just_dealerships:updateDisplays", function(display)
    for k, v in pairs(playersInDealerships) do
        if v.player ~= source then
            TriggerClientEvent('just_dealerships:updateTable', v.player, display)
        end
    end
end)

RegisterServerEvent("just_dealerships:getDisplays")
AddEventHandler("just_dealerships:getDisplays", function(dealership)
    local dealearshipDisplays = {}
    for k, v in pairs(Displays) do
        if v.dealership == dealership then
            table.insert(dealearshipDisplays,  v)
        end
    end
    TriggerClientEvent('just_dealerships:sendDisplays', source, dealearshipDisplays)
end)

RegisterServerEvent("just_dealerships:removeDisplayVehicle")
AddEventHandler("just_dealerships:removeDisplayVehicle", function(dealership, display)
    for k, v in pairs(Config.Dealerships) do
        if v.zone.name == dealership then
            for k2, v2 in pairs(Displays) do
                if v2.display == display then
                    TriggerEvent('just_dealerships:updateDisplays', display)
                    table.remove(Displays, k2)
                end                
            end
        end
    end
end)

RegisterServerEvent("just_dealerships:setDisplayVehicle")
AddEventHandler("just_dealerships:setDisplayVehicle", function(data)
    table.insert(Displays,  {
        dealership = data.dealership,
        display = data.display,
        vehicleName = data.vehicleName,
    })
end)

RegisterServerEvent("just_dealerships:getDealershipVehicles")
AddEventHandler("just_dealerships:getDealershipVehicles", function(dealership, display)
    local purchasableVehicles = {}
    for k, v in pairs(Config.Dealerships[dealership].dealershipVehicles) do
        table.insert(purchasableVehicles,  {
            name = v,
            price = Config.AllVehicles[v].price
        })
    end
    TriggerClientEvent('just_dealerships:viewDealershipVehicles', source, purchasableVehicles, display)
end)


RegisterServerEvent("just_dealerships:confirmCustomerPurchase")
AddEventHandler("just_dealerships:confirmCustomerPurchase", function(args, player, financed, financeLength, downPayment)
    TriggerClientEvent('just_dealerships:confirmPurchase', player, args, nil, financed, financeLength, downPayment, true, source)
end)

RegisterServerEvent("just_dealerships:checkPeopleWorking")
AddEventHandler("just_dealerships:checkPeopleWorking", function(job, fromDealer)
	local xPlayer = ESX.GetPlayerFromId(source)
    local Players = ESX.GetPlayers()
    local playersWorking = false
    if Config.allowPurchaseWithoutDealer and job ~= nil then
        for i = 1, #Players, 1 do
            local tPlayer = ESX.GetPlayerFromId(Players[i])
            if tPlayer.job.name == job then
                playersWorking = true
                break
            end
        end
    elseif job ~= nil then
        playersWorking = true
    end
    if playersWorking == true and job ~= nil then
        if xPlayer.job.name == job or fromDealer then
            TriggerClientEvent('just_dealerships:showMenu', source, "purchase_confirmation_menu", true)
        else 
			TriggerClientEvent("just_dealerships:notification",source , "Go speak to a dealer", nil, "inform")
        end
    else
        TriggerClientEvent('just_dealerships:showMenu', source, "purchase_confirmation_menu", true)
    end
end)

ESX.RegisterServerCallback('just_dealerships:isPlateTaken', function(source, cb, plate)
	MySQL.query('SELECT 1 FROM owned_vehicles WHERE plate = @plate', {
		['@plate'] = plate
	}, function(result)
		cb(result[1] ~= nil)
	end)
end)

ESX.RegisterServerCallback('just_dealerships:buyVehicle', function(source, cb, model, plate, vehicleType, dealership, label, dealerID)
    local xPlayer = ESX.GetPlayerFromId(source)
    local Players = ESX.GetPlayers()
    local playersWorking = false
    for i = 1, #Players, 1 do
        local tPlayer = ESX.GetPlayerFromId(Players[i])

        if tPlayer.job.name == dealership.job then
            playersWorking = true
            break
        end
    end
    local price = Config.AllVehicles[model].price
    local balance

    if not playersWorking then 
        price = math.floor(price * dealership.noDealerUpcharge)
    end

    if Config.usePEFCL then
        balance = exports.pefcl:getDefaultAccountBalance(source)
    else 
        balance = xPlayer.getAccount('bank').money
    end
    if price and balance.data >= price then
		MySQL.update('INSERT INTO owned_vehicles (owner, plate, vehicle, type) VALUES (@owner, @plate, @vehicle, @type)', {
			['@owner']   = xPlayer.identifier,
			['@plate']   = plate,
			['@vehicle'] = json.encode({model = GetHashKey(model), plate = plate}),
			['@type']    = vehicleType,
		}, function(rowsChanged)
            if dealerID ~= nil and Config.usePEFCL and Config.giveDealerCommision then 
                exports.pefcl:addBankBalance(dealerID, { amount = (price * Config.dealerCommision), message = ((Config.dealerCommision*100).."% commission on sale of a "..label) })
            elseif dealerID ~= nil and Config.giveDealerCommision then 
                local tPlayer = ESX.GetPlayerFromId(dealerID)
                tPlayer.addAccountMoney('bank', (price * Config.dealerCommision))
            end
            if Config.usePEFCL then
                exports.pefcl:removeBankBalance(source, { amount = price, message = ("Purchase of a "..label) })
            else 
                xPlayer.removeAccountMoney('bank', price)
            end
			
			TriggerClientEvent("just_dealerships:notification",source , "A "..label.." now belongs to you","Plate: "..plate, "success")
			cb(true)
		end)
	else
		cb(false)
	end
end)

ESX.RegisterServerCallback('just_dealerships:dealearCheck', function(source, cb, job)
	local xPlayer = ESX.GetPlayerFromId(source)
    local Players = ESX.GetPlayers()
    local playersWorking = false
    for i = 1, #Players, 1 do
        local tPlayer = ESX.GetPlayerFromId(Players[i])
        if tPlayer.job.name == job then
            playersWorking = true
            break
        end
    end
    if playersWorking then
		cb(true)
	else
		cb(false)
	end
end)

---------------
-- Financing --
---------------

RegisterServerEvent("just_dealerships:getFinancedVehicles")
AddEventHandler("just_dealerships:getFinancedVehicles", function()
	local xPlayer = ESX.GetPlayerFromId(source)
    local _source = source

    local financedVehicles = MySQL.query.await('SELECT * FROM owned_vehicles WHERE owner = @owner AND financed = @financed', {['@owner'] = xPlayer.identifier, ['@financed'] = "1"})
    local repoedVehicles = MySQL.query.await('SELECT * FROM repoed_vehicles WHERE owner = @owner', {['@owner'] = xPlayer.identifier})
    if financedVehicles or repoedVehicles then
        TriggerClientEvent('just_dealerships:finaceCheckMenu', _source, financedVehicles, repoedVehicles)
    end
end)

ESX.RegisterServerCallback('just_dealerships:financeVehicle', function(source, cb, model, plate, vehicleType, financeLength, downPayment, label, dealerID)
	local xPlayer = ESX.GetPlayerFromId(source)
    local price = Config.AllVehicles[model].price
    local balance
    local downPayment = downPayment / 100
    downPayment = math.floor(downPayment * price)
    local weeklyPayment = math.floor((((price - (downPayment)) * (1 + (Config.financeInterest * financeLength))) / financeLength))

    if Config.usePEFCL then
        balance = exports.pefcl:getDefaultAccountBalance(source)
        balance = balance.data
    else
        balance = xPlayer.getAccount('bank').money
    end

    if downPayment and balance >= downPayment then
        local t = os.time()
        local date = os.date("%Y%m%d",t)
        local renewDate = t + 7 * 24 * 60 * 60
		MySQL.update('INSERT INTO owned_vehicles (owner, plate, vehicle, type, financed, weeklypayment, rempayments, nextpayment) VALUES (@owner, @plate, @vehicle, @type, @financed, @weeklypayment, @rempayments, @nextpayment)', {
			['@owner']          = xPlayer.identifier,
			['@plate']          = plate,
			['@vehicle']        = json.encode({model = GetHashKey(model), plate = plate}),
			['@type']           = vehicleType,
            ['@financed']       = 1,
            ['@weeklypayment']  = weeklyPayment,
            ['@rempayments']    = financeLength,
            ['@nextpayment']    = os.date("%Y%m%d",renewDate),
		}, function(rowsChanged)
            if Config.usePEFCL then
                if Config.giveDealerCommision then
                    exports.pefcl:addBankBalance(dealerID, { amount = (price * Config.dealerCommision), message = ((Config.dealerCommision*100).."% commission on sale of a "..label) })
                end
                exports.pefcl:removeBankBalance(source, { amount = price, message = ("Purchase of a "..label) })
            else
                if Config.giveDealerCommision then
                    local tPlayer = ESX.GetPlayerFromId(dealerID)
                    tPlayer.addAccountMoney('bank', (price * Config.dealerCommision))
                end
                xPlayer.removeAccountMoney('bank', price)
            end
			TriggerClientEvent("just_dealerships:notification",source , "A "..label.." now belongs to you","Plate: "..plate, "success")
			cb(true)
		end)
	else
		cb(false)
	end
end)

RegisterServerEvent("just_dealerships:makePayment")
AddEventHandler("just_dealerships:makePayment", function(plate, amount, owner, vehicleModel, payFull)
    local _source = source
	local xPlayer = ESX.GetPlayerFromId(_source)
    local amount = amount
    local balance
    local paymentsLeft = MySQL.scalar.await('SELECT rempayments FROM owned_vehicles WHERE plate = @plate', {['@plate'] = plate})
    if payFull then
        amount = amount * paymentsLeft
    end

    if Config.usePEFCL then
        balance = exports.pefcl:getDefaultAccountBalance(source)
        balance = balance.data
    else
        balance = xPlayer.getAccount('bank').money
    end

    if amount <= balance then
        local t = os.time()
        local date = os.date("%Y%m%d",t)
        local d = 7
        local renewDate = t + d * 24 * 60 * 60
        paymentsLeft = paymentsLeft- 1
        MySQL.update.await('UPDATE owned_vehicles SET rempayments = @rempayments WHERE plate = @plate', {['@plate'] = plate, ['@rempayments'] = paymentsLeft})
        if paymentsLeft == 0 or payFull then
            MySQL.update.await('UPDATE owned_vehicles SET financed = @financed WHERE plate = @plate', {['@plate'] = plate, ['@financed'] = 0})
            TriggerClientEvent("just_dealerships:notification",_source, "Payment made", "You've fully paid off your "..vehicleModel, "success")
            if Config.usePEFCL then
                exports.pefcl:removeBankBalance(_source, {amount = amount, message = vehicleModel.." final finance payment" })
            else
                xPlayer.removeAccountMoney('bank', amount)
            end
        else 
            TriggerClientEvent("just_dealerships:notification",_source, "Payment made", paymentsLeft.." payments remaining", "success")
            if Config.usePEFCL then
                exports.pefcl:removeBankBalance(_source, {amount = amount, message = vehicleModel.." finance payment "..paymentsLeft.." payments remaining" })
            else
                xPlayer.removeAccountMoney('bank', amount)
            end
            MySQL.update.await('UPDATE owned_vehicles SET nextpayment = @nextpayment WHERE plate = @plate', {['@plate'] = plate, ['@nextpayment'] = os.date("%Y%m%d",renewDate)})
        end
    else
        TriggerClientEvent("just_dealerships:notification",_source, "Not enough money", nil, "error")
    end
end)

AddEventHandler('onServerResourceStart', function(resourceName)
    if resourceName == 'just_dealerships' or resourceName == GetCurrentResourceName() then
        MySQL.query('SELECT * FROM owned_vehicles WHERE financed = @financed', {
            ['@financed'] = 1,
        }, function(vehicles)
            for i=1, #vehicles, 1 do
                local todaysDate = tonumber(os.date("%Y%m%d",os.time()))
                if todaysDate > vehicles[i].nextpayment and vehicles[i].financed == 1 then
                    -- local xPlayer = ESX.GetPlayerFromIdentifier(vehicles[i].owner)
                    local balance
                    local accounts
                    if Config.usePEFCL then
                        balance = exports.pefcl:getTotalBankBalanceByIdentifier(source, vehicles[i].owner)
                        balance = balance.data
                    else 
                        accounts = MySQL.scalar.await('SELECT accounts FROM users WHERE identifier = @identifier', {['@identifier'] = vehicles[i].owner})
                        accounts = json.decode(accounts)
                        balance = accounts.bank
                    end
                    if vehicles[i].weeklypayment <= balance then
                        local t = os.time()
                        local date = os.date("%Y%m%d",t)
                        local d = 7
                        local renewDate = t + d * 24 * 60 * 60
                        local paymentsLeft = vehicles[i].rempayments - 1
                        MySQL.update.await('UPDATE owned_vehicles SET nextpayment = @nextpayment WHERE plate = @plate', {['@plate'] = vehicles[i].plate, ['@nextpayment'] = os.date("%Y%m%d",renewDate)})
                        MySQL.update.await('UPDATE owned_vehicles SET rempayments = @rempayments WHERE plate = @plate', {['@plate'] = vehicles[i].plate, ['@rempayments'] = paymentsLeft})
                        if Config.usePEFCL then
                            exports.pefcl:removeBankBalanceByIdentifier(source, { identifier = vehicles[i].owner, amount = vehicles[i].weeklypayment, message = "Vehicle finance payment "..paymentsLeft.." payments remaining" })
                        else 
                            accounts.bank = accounts.bank - vehicles[i].weeklypayment
                            MySQL.update.await('UPDATE users SET accounts = @accounts WHERE identifier = @identifier', {['@identifier'] = vehicles[i].owner, ['@accounts'] = json.encode(accounts)})
                        end
                        if paymentsLeft == 0 then
                            MySQL.update.await('UPDATE owned_vehicles SET financed = @financed WHERE plate = @plate', {['@plate'] = vehicles[i].plate, ['@financed'] = 0})
                        end
                    elseif vehicles[i].paymentsoverdue > Config.maxMissedPayments then
                        TriggerEvent("just_dealerships:repoVehicle", vehicles[i].plate)
                    else
                        local t = os.time()
                        local date = os.date("%Y%m%d",t)
                        local d = 7
                        local renewDate = t + d * 24 * 60 * 60
                        MySQL.update.await('UPDATE owned_vehicles SET nextpayment = @nextpayment WHERE plate = @plate', {['@plate'] = vehicles[i].plate, ['@nextpayment'] = os.date("%Y%m%d",renewDate)})
                        MySQL.update.await('UPDATE owned_vehicles SET paymentsoverdue = @paymentsoverdue WHERE plate = @plate', {['@plate'] = vehicles[i].plate, ['@paymentsoverdue'] = ( vehicles[i].paymentsoverdue + 1)})
                    end
                end
            end
        end)
    end
end)


----------
-- Repo --
----------

RegisterServerEvent("just_dealerships:repoVehicle")
AddEventHandler("just_dealerships:repoVehicle", function(plate)
    MySQL.single('SELECT * FROM owned_vehicles WHERE plate = ?', {plate}, function(row)
        if row then
            MySQL.insert('INSERT INTO repoed_vehicles (owner, plate, vehicle, type, job, weeklypayment, rempayments, paymentsoverdue) VALUES (?, ?, ?, ?, ?, ?, ?, ?)', {row.owner, row.plate, row.vehicle, row.type, row.job, row.weeklypayment, row.rempayments, row.paymentsoverdue}, function(changed)
                if changed then
                    -- print(changed)
                    MySQL.update('DELETE FROM owned_vehicles WHERE plate = @plate', {['@plate'] = plate}, function(affectedRows)
                        if affectedRows then
                            print(plate.." Repoed from "..row.owner)
                        else
                            TriggerClientEvent("just_dealerships:notification",source, "Something went wrong", nil, "error")
                        end
                    end)
                else
                    TriggerClientEvent("just_dealerships:notification",source, "Something went wrong", nil, "error")
                end
            end)
        else 
            TriggerClientEvent("just_dealerships:notification",source, "Something went wrong", nil, "error")
        end
    end)
end)

RegisterServerEvent("just_dealerships:recoverRepoedVehicle")
AddEventHandler("just_dealerships:recoverRepoedVehicle", function(plate, vehicleModel)
    local _source = source
    MySQL.single('SELECT * FROM repoed_vehicles WHERE plate = ?', {plate}, function(row)
        if row then
            local balance
            local accounts
            if Config.usePEFCL then
                balance = exports.pefcl:getTotalBankBalanceByIdentifier(_source, row.owner)
                balance = balance.data
            else
                accounts = MySQL.scalar.await('SELECT accounts FROM users WHERE identifier = @identifier', {['@identifier'] = row.owner})
                accounts = json.decode(accounts)
                balance = accounts.bank
            end
            local repoCost = ((row.rempayments * row.weeklypayment) * Config.repoFine)
            if repoCost <= balance then
                MySQL.insert('INSERT INTO owned_vehicles (owner, plate, vehicle, type, job, weeklypayment) VALUES (?, ?, ?, ?, ?, ?)', {row.owner, row.plate, row.vehicle, row.type, row.job, row.weeklypayment}, function(changed)
                    if changed then
                        -- print(changed)
                        MySQL.update('DELETE FROM repoed_vehicles WHERE plate = @plate', {['@plate'] = row.plate}, function(affectedRows)
                            if affectedRows then
                                TriggerClientEvent("just_dealerships:notification",_source, "Successfully recovered "..vehicleModel.." from repo", "Plate: "..row.plate, "success")
                                if Config.usePEFCL then
                                    exports.pefcl:removeBankBalanceByIdentifier(_source, { identifier = row.owner, amount = row.weeklypayment, message = "Recovered repoed "..vehicleModel})
                                else 
                                    accounts.bank = accounts.bank - row.weeklypayment
                                    MySQL.update.await('UPDATE users SET accounts = @accounts WHERE identifier = @identifier', {['@identifier'] = row.owner, ['@accounts'] = json.encode(accounts)})
                                end
                                print(plate.." Recovered by "..row.owner)
                            else
                                TriggerClientEvent("just_dealerships:notification",_source, "Something went wrong", nil, "error")
                            end
                        end)
                    else
                        TriggerClientEvent("just_dealerships:notification",_source, "Something went wrong", nil, "error")
                    end
                end)
            else
                TriggerClientEvent("just_dealerships:notification",_source, "Not enough money", nil, "error")
            end
        else 
            TriggerClientEvent("just_dealerships:notification",_source, "Something went wrong", nil, "error")
        end
    end)
end)

RegisterServerEvent("just_dealerships:abandonRepoedVehicle")
AddEventHandler("just_dealerships:abandonRepoedVehicle", function(plate)
    local _source = source
    MySQL.update('DELETE FROM repoed_vehicles WHERE plate = @plate', {['@plate'] = plate}, function(affectedRows)
        if affectedRows then
            TriggerClientEvent("just_dealerships:notification",_source, "Successfully abandoned vehicle", "Plate: "..plate, "success")
        else
            TriggerClientEvent("just_dealerships:notification",_source, "Something went wrong", nil, "error")
        end
    end)
end)

------------------------------------
-- Give Vehicle To Another Player --
------------------------------------

ESX.RegisterServerCallback('just_dealerships:requestPlayerCars', function(source, cb, plate)
	local xPlayer = ESX.GetPlayerFromId(source)
	MySQL.query('SELECT * FROM owned_vehicles WHERE owner = @identifier',{
			['@identifier'] = xPlayer.identifier
		},function(result)
			local found = false
			for i=1, #result, 1 do
				local vehicleProps = json.decode(result[i].vehicle)
				if vehicleProps.plate == plate then
					found = true
					break
				end
			end
			if found then
				cb(true)
			else
				cb(false)
			end
		end
	)
end)

RegisterServerEvent('just_dealerships:setVehicleOwnedPlayerId')
AddEventHandler('just_dealerships:setVehicleOwnedPlayerId', function (playerId, vehicleProps)
	local xPlayer = ESX.GetPlayerFromId(playerId)
	MySQL.update('UPDATE owned_vehicles SET owner=@owner WHERE plate=@plate',
	{
		['@owner']   = xPlayer.identifier,
		['@plate']   = vehicleProps.plate
	},
	function (rowsChanged)
		TriggerClientEvent('esx:showNotification', playerId, 'You have got a new car with plate ' ..vehicleProps.plate..'!', vehicleProps.plate)
	end)
end)
RegisterCommand("sradio", function(source, args, rawCommands)
    if source ~= 0 then
        print("This command can only be used from console.")
        return
    end
    if not args[1] then
        print("Missing command. Try \"sradio help\" fro help.")
        return
    end
    if args[1] == "help" then
        print([[
SonoranRadio Help
    help - shows this message
    update - attempt to update the radio script
]])
    elseif args[1] == "update" then
        print('Attempting to auto update...')
        RunAutoUpdater(true)
    else
        print('Missing command. Try \"sradio help\" for help.')
    end
end, true)
-- No fuel script: GTA does not use up fuel by itself, so the fuel is only tracked in the car's
-- `fuel` state bag (full until something takes some), and set on the car too.
local provider, shared = ...
return shared.stateClient(100.0)

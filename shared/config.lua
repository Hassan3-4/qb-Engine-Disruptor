Config = {}

-- General toggles
Config.enabled = true
Config.rangeMeters = 15.0
Config.armHoldMs = 1000
Config.lockSeconds = 30
Config.officerCooldownSeconds = 300 -- 180-600 allowed
Config.perTargetCooldownSeconds = 90

-- Jobs & usage
Config.allowedJobs = { police = true }
Config.requirePoliceVehicle = true
Config.nearPoliceVehicleMeters = 3.0
Config.requireSirenOn = false
Config.minTargetSpeedKmh = 0

-- Exclusions
Config.excludeJobs = { police = true, ambulance = true, ems = true, fire = true }
Config.excludeClasses = { [8]=true, [14]=true, [15]=true, [16]=true } -- bikes(8), boats(14), helis(15), planes(16)
Config.excludeNPC = true

-- Model filters
Config.modelWhitelist = {}
Config.modelBlacklist = {
    'police','police2','police3','police4','policeb','policet','sheriff','sheriff2'
}
Config.policeVehicleModels = {
    'police','police2','police3','police4','policeb','policet','sheriff','sheriff2'
}

-- Deceleration profiles (kmh targets and durations seconds)
Config.decelProfiles = {
    { minSpeed = 120.0, targetSpeed = 40.0, duration = 6.0 },
    { minSpeed = 40.0, targetSpeed = 20.0, duration = 4.0 },
    { minSpeed = 0.0, targetSpeed = 2.0, duration = 2.0 },
}

-- Stacking
Config.allowRefresh = true
Config.refreshWindowSeconds = 5
Config.refreshMaxCount = 1

-- Safe-zones (simple spheres)
Config.enableSafeZones = true
Config.safeZones = { -- { coords = vector3(x,y,z), radius = 50.0 }
}

-- UI/SFX
Config.showOfficerHints = true
Config.showCivilianNotify = true
Config.showHudTimer = true
Config.playSfx = true

-- Item config
Config.itemName = 'engine_disruptor'
Config.defaultCharges = 3 -- initial charges if spawning

-- Utility
Config.debug = false

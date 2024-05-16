-- Initializing global variables to store the latest game state and game host process.
LatestGameState = LatestGameState or nil
Game = Game or "wudLa8_VIjHZ6VA5ZG1ZHZs5CYkaIUw4Je_ePYEqmGQ"
CRED = CRED or "Sa0iBLPNyJQrwpTTG-tWLQU-1QeUAJA73DdxGGiKoJc"
Counter = Counter or 0

colors = {
  red = "\27[31m",
  green = "\27[32m",
  blue = "\27[34m",
  reset = "\27[0m",
  gray = "\27[90m"
}

-- Checks if two points are within a given range.
-- @param x1, y1: Coordinates of the first point.
-- @param x2, y2: Coordinates of the second point.
-- @param range: The maximum allowed distance between the points.
-- @return: Boolean indicating if the points are within the specified range.
function inRange(x1, y1, x2, y2, range)
    return math.abs(x1 - x2) <= range and math.abs(y1 - y2) <= range
end

-- Function to provide a vibration effect when moving
function vibrate()
  print(colors.gray .. "Vibrating..." .. colors.reset)
end

-- Function to deal damage to nearby players based on their position
function dealDamage()
  local player = LatestGameState.Players[ao.id]
  local damageDealt = false

  for target, state in pairs(LatestGameState.Players) do
    if target ~= ao.id then
      local dx = state.x - player.x
      local dy = state.y - player.y
      local damage = 0

      -- Front
      if dx == 0 and dy == -1 then
        damage = 5
      -- Right
      elseif dx == 1 and dy == 0 then
        damage = 3
      -- Left
      elseif dx == -1 and dy == 0 then
        damage = 3
      -- Behind
      elseif dx == 0 and dy == 1 then
        damage = 1
      end

      if damage > 0 then
        ao.send({Target = Game, Action = "PlayerAttack", AttackEnergy = tostring(damage)})
        damageDealt = true
        print(colors.red .. "Dealing " .. damage .. " points of damage to player at (" .. state.x .. ", " .. state.y .. ")" .. colors.reset)
      end
    end
  end

  return damageDealt
end

-- Decides the next action based on player proximity and energy.
-- If any player is within range, it initiates an attack; otherwise, moves randomly.
function decideNextAction()
  local player = LatestGameState.Players[ao.id]
  local targetInRange = false

  for target, state in pairs(LatestGameState.Players) do
      if target ~= ao.id and inRange(player.x, player.y, state.x, state.y, 1) then
          targetInRange = true
          break
      end
  end

  vibrate() -- Add vibration effect when deciding the next action

  if player.energy > 10 and targetInRange then
    print(colors.red .. "Player in range. Attacking..." .. colors.reset)
    ao.send({Target = Game, Action = "PlayerAttack", AttackEnergy = tostring(player.energy)})
  elseif not dealDamage() then -- If no damage was dealt, proceed with movement
    local directionMap = {"Up", "Down", "Left", "Right", "UpRight", "UpLeft", "DownRight", "DownLeft"}
    local randomIndex = math.random(#directionMap)
    ao.send({Target = Game, Action = "PlayerMove", Direction = directionMap[randomIndex]})
  end
end

-- Handler to print game announcements and trigger game state updates.
Handlers.add(
  "PrintAnnouncements",
  Handlers.utils.hasMatchingTag("Action", "Announcement"),
  function (msg)
    ao.send({Target = Game, Action = "GetGameState"})
    print(colors.green .. msg.Event .. ": " .. msg.Data .. colors.reset)
    print("Location: " .. "row: " .. LatestGameState.Players[ao.id].x .. ' col: ' .. LatestGameState.Players[ao.id].y)
  end
)

-- Handler to trigger game state updates.
Handlers.add(
  "GetGameStateOnTick",
  Handlers.utils.hasMatchingTag("Action", "Tick"),
  function ()
      ao.send({Target = Game, Action = "GetGameState"})
  end
)

-- Handler to update the game state upon receiving game state information.
Handlers.add(
  "UpdateGameState",
  Handlers.utils.hasMatchingTag("Action", "GameState"),
  function (msg)
    local json = require("json")
    LatestGameState = json.decode(msg.Data)
    ao.send({Target = ao.id, Action = "UpdatedGameState"})
    print("Location: " .. "row: " .. LatestGameState.Players[ao.id].x .. ' col: ' .. LatestGameState.Players[ao.id].y)
  end
)

-- Handler to decide the next best action.
Handlers.add(
  "decideNextAction",
  Handlers.utils.hasMatchingTag("Action", "UpdatedGameState"),
  function ()
    decideNextAction()
    ao.send({Target = ao.id, Action = "Tick"})
  end
)

-- Handler to automatically attack when hit by another player.
Handlers.add(
  "ReturnAttack",
  Handlers.utils.hasMatchingTag("Action", "Hit"),
  function (msg)
    local playerEnergy = LatestGameState.Players[ao.id].energy
    if playerEnergy == undefined then
      print(colors.red .. "Unable to read energy." .. colors.reset)
      ao.send({Target = Game, Action = "Attack-Failed", Reason = "Unable to read energy."})
    elseif playerEnergy > 10 then
      print(colors.red .. "Player has insufficient energy." .. colors.reset)
      ao.send({Target = Game, Action = "Attack-Failed", Reason = "Player has no energy."})
    else
      print(colors.red .. "Returning attack..." .. colors.reset)
      ao.send({Target = Game, Action = "PlayerAttack", AttackEnergy = tostring(playerEnergy)})
    end
    ao.send({Target = ao.id, Action = "Tick"})
  end
)

Handlers.add(
  "ReSpawn",
  Handlers.utils.hasMatchingTag("Action", "Eliminated"),
  function (msg)
    print("Eliminated! " .. "Playing again!")
    Send({Target = CRED, Action = "Transfer", Quantity = "1000", Recipient = Game})
  end
)

Handlers.add(
  "StartTick",
  Handlers.utils.hasMatchingTag("Action", "Payment-Received"),
  function (msg)
    Send({Target = Game, Action = "GetGameState", Name = Name, Owner = Owner })
    print('Start Moooooving!')
  end
)

Prompt = function () return Name .. "> " end

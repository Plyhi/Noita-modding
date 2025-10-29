-- files/DropScheduler.lua
-- Minimal scheduler to drop entities one-per-frame along a horizontal line above an origin entity.

drop_queue = drop_queue or {}

-- Queue a "rain" of entities (spell cards) above an origin entity.
-- cards: array of entity ids (spell cards)
-- origin_eid: player or donor wand; for "above head", use player
-- opts: { range_px=number, dy_px=number, spacing=frames, burst=number }
function queue_spell_rain(cards, origin_eid, opts)
  opts = opts or {}
  local range_px = opts.range_px or 90
  local dy_px    = opts.dy_px or -18
  local spacing  = opts.spacing or 1   -- one per frame by default
  local burst    = math.max(1, opts.burst or 1)

  if (not origin_eid) or (EntityGetIsAlive and not EntityGetIsAlive(origin_eid)) then return end

  local px, py = EntityGetTransform(origin_eid)
  local y_line = py + dy_px
  local frame0 = GameGetFrameNum()

  for i, card in ipairs(cards) do
    if EntityGetIsAlive(card) then
      -- Detach immediately so deleting the wand won't delete the card.
      pcall(function() EntityRemoveFromParent(card) end)
      -- Keep hidden until its turn.
      pcall(function() EntitySetComponentsWithTagEnabled(card, "enabled_in_world", false) end)
      pcall(function() EntitySetComponentsWithTagEnabled(card, "enabled_in_inventory", false) end)

      -- Unique horizontal offset per item.
      SetRandomSeed(math.floor(px + frame0) + i * 131, math.floor(py) + i * 71)
      local dx = Randomf(-range_px * 0.5, range_px * 0.5)

      table.insert(drop_queue, {
        eid   = card,
        x     = px + dx,
        y     = y_line,
        frame = frame0 + math.floor((i - 1) / burst) * spacing
      })
    end
  end
end

function process_drop_queue()
  if not drop_queue or #drop_queue == 0 then return end
  local now = GameGetFrameNum()
  local i = 1
  while i <= #drop_queue do
    local item = drop_queue[i]
    if item.frame <= now then
      local eid = item.eid
      if EntityGetIsAlive(eid) then
        -- Enable in world and place it
        pcall(function() EntitySetComponentsWithTagEnabled(eid, "enabled_in_world", true) end)
        pcall(function() EntitySetComponentsWithTagEnabled(eid, "enabled_in_inventory", false) end)
        EntitySetTransform(eid, item.x, item.y)

        local item_comp = EntityGetFirstComponentIncludingDisabled(eid, "ItemComponent")
        if item_comp ~= nil then
          ComponentSetValue2(item_comp, "has_been_picked_by_player", false)
          ComponentSetValue2(item_comp, "permanently_attached", false)
        end
        local vc = EntityGetFirstComponentIncludingDisabled(eid, "VelocityComponent")
        if vc ~= nil then
          ComponentSetValue2(vc, "mVelocity", 0, 0)
        end
      end
      table.remove(drop_queue, i)
    else
      i = i + 1
    end
  end
end

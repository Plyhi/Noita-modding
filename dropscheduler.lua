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
--------find a free position according to parallel position siries--------
      local x_free, y_free = FindFreePositionForBody(px + dx,y_line,0,0,5)

-------hit raytrace redius---------	
      local safe_radius = 3

    local directions = {
    {0, -safe_radius},  -- up
    {safe_radius, 0},   -- right  
    {0, safe_radius},    -- down
    {-safe_radius, 0}   -- left
    }			
-------if still hit then spawn at player--------
    local is_safe = true
      for _, dir in ipairs(directions) do
   	local hit, hit_x, hit_y = Raytrace(x_free,  y_free, x_free + dir[1], y_free + dir[2])
    	  if hit then
        		is_safe = false
		x_free = px
		y_free = py
        		break
    	  end
      end
----------insert spell to table---------
      table.insert(drop_queue, {
        eid   = card,
        x     = x_free,
        y     = y_free,
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
        pcall(function() EntitySetComponentsWithTagEnabled(eid, "item_unidentified", false) end)
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


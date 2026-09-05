local compviz = pd.Class:new():register("comp-viz")

local PAD = 0
-- input and output share the same dB range/scale, so the diagonal is a
-- true 45 degrees and a segment's slope is directly its ratio.
local DB_MIN = -60
local DB_MAX = 0
local PLOT = 220 -- square plot area, in px

local function default_side(threshold)
    return { level = -120, gain = 0, threshold = threshold, ratio_inv = 1, knee = 6, amount = 100 }
end

function compviz:initialize(sel, atoms)
    self.inlets = 2
    self:set_size(PLOT + 2 * PAD, PLOT + 2 * PAD)

    -- Up (inlet 0) and Down (inlet 1) are applied in series on the same
    -- signal (dyn.pd: Input Gain -> Upward -> Downward -> Output Gain), so
    -- this draws ONE composite curve instead of two separate ones.
    self.up = default_side(-60)
    self.down = default_side(-20)

    return true
end

-- Mirrors stage.pd's expr~ chain (object index 4: diff, index 8: gain), so
-- the drawn curve never diverges from what the patch actually computes.
local function kneed(diff, knee)
    if knee <= 0 then
        return math.max(diff, 0)
    elseif diff >= knee then
        return diff
    elseif diff <= -knee then
        return 0
    else
        return (diff + knee) * (diff + knee) / (4 * knee)
    end
end

local function gain_db(direction, level, threshold, ratio_inv, knee, amount)
    local diff = direction * (math.max(level, -120) - threshold)
    return direction * (amount * 0.01) * (ratio_inv - 1) * kneed(diff, knee)
end

-- Chains Up then Down, exactly like the real signal path.
local function composite_output(x_db, up, down)
    local mid = x_db + gain_db(-1, x_db, up.threshold, up.ratio_inv, up.knee, up.amount)
    return mid + gain_db(1, mid, down.threshold, down.ratio_inv, down.knee, down.amount)
end

local function read_side(side, atoms)
    side.level = atoms[1] or side.level
    side.gain = atoms[2] or side.gain
    side.threshold = atoms[3] or side.threshold
    side.ratio_inv = atoms[4] or side.ratio_inv
    side.knee = atoms[5] or side.knee
    side.amount = atoms[6] or side.amount
end

function compviz:in_1_list(atoms)
    read_side(self.up, atoms)
    self:repaint()
end

function compviz:in_2_list(atoms)
    read_side(self.down, atoms)
    self:repaint()
end

-- db_to_px: same mapping for both axes, so equal dB distances are equal
-- pixel distances on X and Y -> a segment's on-screen angle IS its ratio.
local function db_to_px(db)
    local t = (db - DB_MIN) / (DB_MAX - DB_MIN)
    return t * PLOT
end

local function x_to_px(x_db)
    return PAD + db_to_px(x_db)
end

local function y_to_px(y_db)
    return PAD + PLOT - db_to_px(y_db)
end

function compviz:paint(g)
    g:set_color(30, 30, 34)
    g:fill_all()

    -- gridlines every 6 dB, both axes (same scale), labeled with the dB value.
    local db = DB_MIN
    while db <= DB_MAX do
        g:set_color(50, 50, 56)
        g:draw_line(x_to_px(db), y_to_px(DB_MIN), x_to_px(db), y_to_px(DB_MAX), 1)
        g:draw_line(x_to_px(DB_MIN), y_to_px(db), x_to_px(DB_MAX), y_to_px(db), 1)

        g:set_color(110, 110, 118, 1)
        g:draw_text(tostring(db), x_to_px(db) + 2, y_to_px(DB_MIN) - 12, 24, 9)
        g:draw_text(tostring(db), x_to_px(DB_MIN) + 2, y_to_px(db) - 10, 24, 9)

        db = db + 6
    end

    -- input highlight: right triangle under the diagonal, from the plot's
    -- bottom-left corner up to the current (original) input level, capped
    -- at the diagonal itself -- nothing above the diagonal line is filled.
    local in_level = self.up.level
    local bl_x, bl_y = x_to_px(DB_MIN), y_to_px(DB_MIN)
    local lvl_x = x_to_px(in_level)
    g:set_color(200, 200, 210, 0.15)
    local tri = Path(bl_x, bl_y)
    tri:line_to(lvl_x, bl_y)
    tri:line_to(lvl_x, y_to_px(in_level))
    tri:close()
    g:fill_path(tri)

    -- diagonal reference: output = input, i.e. no processing at all.
    g:set_color(80, 80, 88)
    g:draw_line(x_to_px(DB_MIN), y_to_px(DB_MIN), x_to_px(DB_MAX), y_to_px(DB_MAX), 1)

    -- threshold: one vertical line per stage (Up = left/quiet side,
    -- Down = right/loud side), nothing printed.
    g:set_color(150, 150, 160)
    g:draw_line(x_to_px(self.up.threshold), y_to_px(DB_MIN), x_to_px(self.up.threshold), y_to_px(DB_MAX), 1)
    g:draw_line(x_to_px(self.down.threshold), y_to_px(DB_MIN), x_to_px(self.down.threshold), y_to_px(DB_MAX), 1)

    -- composite transfer curve: Up's boost on the left, flat in the middle,
    -- Down's reduction on the right -- one curve, split left/right.
    g:set_color(255, 255, 255, 1)
    local curve = nil
    local steps = 120
    for i = 0, steps do
        local x_db = DB_MIN + (DB_MAX - DB_MIN) * (i / steps)
        local y_db = composite_output(x_db, self.up, self.down)
        local px, py = x_to_px(x_db), y_to_px(y_db)
        if curve then
            curve:line_to(px, py)
        else
            curve = Path(px, py)
        end
    end
    g:stroke_path(curve, 2)

    -- live operating point: original input level (Up's tap) vs. the true
    -- end-to-end output. Down's level tap already reflects Up's effect
    -- (it's measured downstream), so down.level + down.gain is the real
    -- final level -- no recomputation, these are the actually-applied values.
    local out_level = self.down.level + self.down.gain
    g:set_color(150, 150, 160)
    g:draw_line(x_to_px(in_level), y_to_px(in_level), x_to_px(in_level), y_to_px(out_level), 1)

    g:set_color(170, 170, 178, 1)
    g:fill_ellipse(x_to_px(in_level) - 4, y_to_px(in_level) - 4, 8, 8)

    g:set_color(255, 255, 255, 1)
    g:fill_ellipse(x_to_px(in_level) - 4, y_to_px(out_level) - 4, 8, 8)

    -- upward gain readout (dB currently applied by the Up stage), bottom-left
    -- corner, offset above the axis labels so the two don't overlap.
    g:set_color(255, 255, 255, 1)
    local up_gain_text = string.format("Up %+.1f dB", self.up.gain)
    g:draw_text(up_gain_text, PAD + 6, y_to_px(DB_MIN) - 30, 100, 14)

    -- safe_max_gain indicator: self.up.gain is the pre-clamp value (stage.pd's
    -- idx8 output feeds this outlet directly, not the post-clamp idx22), so
    -- comparing it against the same ceiling formula the clamp itself uses
    -- tells us whether the clamp is actively limiting right now, with no new
    -- wiring needed in stage.pd/dyn.pd.
    local up_ceiling = (self.up.amount * 0.01) * (1 - self.up.ratio_inv) * kneed(self.up.threshold - self.up.level, self.up.knee)
    if self.up.gain > up_ceiling + 0.05 then
        g:set_color(220, 60, 60, 1)
    else
        g:set_color(150, 150, 150, 0.25)
    end
    g:fill_ellipse(PLOT - 20, PLOT - 20, 10, 10)

    -- clamp cut amount (dB currently being shaved off by safe_max_gain), so we
    -- can tell a large emergency correction apart from a negligible one even
    -- while the binary indicator above is lit.
    local up_cut = math.max(0, self.up.gain - up_ceiling)
    g:set_color(255, 255, 255, 1)
    local up_cut_text = string.format("Cut %.2f dB", up_cut)
    g:draw_text(up_cut_text, PLOT - 80, PLOT - 34, 76, 14)
end

#!/usr/bin/env lua

local solid = require("solid")
solid.defaultCenter(true)

---@class Measures
---@field pcbWidth number
---@field pcbDepth number
---@field thickness number
---@field baseHeight number
---@field needleLandingHeight number
---@field needleDiameter number
---@field cornerX number
---@field cornerY number
---@field hexColumnDiameter number
---@field hexColumnScrewDiameter number
---@field hexNutHeight number
---@field hexColumnShift number
---@field holderScrewXShift number
---@field holderScrewYShift number
---@field holderBaseWidth number
---@field holderBaseDepth number
---@field shortHolderHeight number
---@field tallHolderHeight number
---@field holderXShift number
---@field leftHolderY1Shift number
---@field leftHolderY2Shift number
---@field leftNeedles1 number[]
---@field leftNeedles2 number[]
---@field rightNeedles number[]
local measures = {
    pcbWidth = 87,
    pcbDepth = 50.5,
    thickness = 2,
    needleLandingHeight = 12,
    baseHeight = 5,
    cornerX = 8,
    cornerY = 20,
    needleDiameter = 3.5,
    hexColumnDiameter = 6.6,
    hexColumnScrewDiameter = 3.4,
    hexNutHeight = 3,
    hexColumnShift = 16,
    holderScrewXShift = 7,
    holderScrewYShift = 7,
    holderBaseWidth = 25,
    holderBaseDepth = 25,
    shortHolderHeight = 16,
    tallHolderHeight = 16,
    holderXShift = 13,
    leftHolderY1Shift = 12.5,
    leftHolderY2Shift = -12.5,
    leftNeedles1 = { 4.85, 6.45 },
    leftNeedles2 = { 4.85, 32.66 },
    rightNeedles = { 81.19, 12.88 },
}

local product = function(t1, t2)
    local result = {}
    for _, el1 in ipairs(t1) do
        for _, el2 in ipairs(t2) do
            table.insert(result, { el1, el2 })
        end
    end
    return result
end

local verticesCenterShift = function(width, depth)
    return product({ width / 2, -width / 2 }, { depth / 2, -depth / 2 })
end

local buildHexColumn = function(diameter, height, screwDiameter, screwHeight)
    local heightShift = 0
    local centerShift = screwHeight / 2

    if screwHeight < 0 then
        screwHeight = -screwHeight
        heightShift = screwHeight + height
        centerShift = -screwHeight / 2
    end
    return
        solid.union {
            solid.literal("$fn=32;\n"),
            solid.cylinder { diameter = screwDiameter, height = screwHeight } >>
            { 0, 0, -(screwHeight - height) / 2 - height + heightShift }
        } +
        solid.union {
            solid.literal("$fn=6;\n"),
            solid.cylinder {
                diameter = diameter,
                height = height,
            }
        } >> { 0, 0, centerShift }
end

---@param m Measures
---@return Solid
local buildHolderBase = function(m, height)
    return solid.cube {
        m.holderBaseWidth,
        m.holderBaseDepth,
        m.baseHeight + height,
    }
end

---@param m Measures
---@return Solid
local buildHolderHoles = function(m, height)
    local holes = buildHexColumn(m.hexColumnDiameter, m.hexNutHeight + height, m.hexColumnScrewDiameter,
        m.baseHeight - m.hexNutHeight)

    for _, v in ipairs(verticesCenterShift(m.holderScrewXShift * 2, m.holderScrewYShift * 2)) do
        holes = holes +
            (buildHexColumn(m.hexColumnDiameter, m.hexNutHeight + height, m.hexColumnScrewDiameter, -m.hexNutHeight) >> {
                v
                    [1], v[2], 0 })
    end

    return holes
end

local needleStrip = function(pos, needle, number)
    local result = { solid.literal("$fn=32;\n") }
    for i = 1, number do
        table.insert(result, needle >> { pos[1], pos[2] + (i - 1) * 5.05, 0 })
    end

    return solid.union(result)
end


---@param m Measures
---@return Solid
local build = function(m)
    local totalHeight = m.baseHeight + m.needleLandingHeight

    local piece =
        solid.difference {
            solid.cube {
                m.pcbWidth + m.thickness * 2,
                m.pcbDepth + m.thickness * 2,
                totalHeight,
            },
            (solid.cube {
                m.pcbWidth,
                m.pcbDepth,
                m.needleLandingHeight,
            }
            + solid.cube {
                m.pcbWidth + m.thickness * 2,
                m.pcbDepth - m.cornerX * 2,
                m.needleLandingHeight,
            }
            + solid.cube {
                m.pcbWidth - m.cornerY * 2,
                m.pcbDepth + m.thickness * 2,
                m.needleLandingHeight,
            }) >> { 0, 0, (totalHeight - m.needleLandingHeight) / 2 },
        }

    piece = piece - ((solid.cylinder { diameter = m.pcbDepth * 3 / 4, height = totalHeight }) * { 1.5 })

    for _, v in ipairs(verticesCenterShift(m.pcbWidth - m.hexColumnDiameter * 2 - m.hexColumnShift, m.pcbDepth - m.hexColumnDiameter)) do
        piece = piece -
            (buildHexColumn(m.hexColumnDiameter, m.hexNutHeight, m.hexColumnScrewDiameter, m.baseHeight) >> { v[1], v[2], (totalHeight - m.baseHeight) /
            2 -
            m.needleLandingHeight })
    end

    do
        piece = piece +
            solid.hull {
                ((solid.rotate({ 0, 0, 90 }, buildHolderBase(m, m.shortHolderHeight)) >>
                { -m.pcbWidth / 2 - m.holderBaseDepth / 2 - m.thickness - m.holderXShift, m.leftHolderY1Shift, -(totalHeight - m.baseHeight - m.tallHolderHeight) /
                2 })),
                (solid.cube { 0.1, m.pcbDepth + m.thickness * 2, m.baseHeight }) >>
                { -m.pcbWidth / 2 - m.thickness + 0.05,
                    0, -(totalHeight - m.baseHeight) / 2 }
            }

        piece = piece +
            solid.hull {
                ((solid.rotate({ 0, 0, 90 }, buildHolderBase(m, m.shortHolderHeight)) >>
                { -m.pcbWidth / 2 - m.holderBaseDepth / 2 - m.thickness - m.holderXShift, m.leftHolderY2Shift, -(totalHeight - m.baseHeight - m.tallHolderHeight) /
                2 })),
                (solid.cube { 0.1, m.pcbDepth + m.thickness * 2, m.baseHeight }) >>
                { -m.pcbWidth / 2 - m.thickness + 0.05,
                    0, -(totalHeight - m.baseHeight) / 2 }
            }

        piece = piece - ((solid.rotate({ 0, 0, 90 }, buildHolderHoles(m, m.shortHolderHeight)) >>
            { -m.pcbWidth / 2 - m.holderBaseDepth / 2 - m.thickness - m.holderXShift, m.leftHolderY1Shift, -(totalHeight - m.baseHeight - m.tallHolderHeight) /
            2 }))
            - ((solid.rotate({ 0, 0, 90 }, buildHolderHoles(m, m.shortHolderHeight)) >>
            { -m.pcbWidth / 2 - m.holderBaseDepth / 2 - m.thickness - m.holderXShift, m.leftHolderY2Shift, -(totalHeight - m.baseHeight - m.tallHolderHeight) /
            2 }))
    end

    do
        piece = piece +
            solid.hull {
                ((solid.rotate({ 0, 0, 90 }, buildHolderBase(m, m.tallHolderHeight)) >>
                { m.pcbWidth / 2 + m.holderBaseDepth / 2 + m.thickness + m.holderXShift, 0, -(totalHeight - m.baseHeight - m.tallHolderHeight) /
                2 })),
                (solid.cube { 0.1, m.pcbDepth + m.thickness * 2, m.baseHeight }) >>
                { m.pcbWidth / 2 + m.thickness - 0.05,
                    0, -(totalHeight - m.baseHeight) / 2 }
            }

        piece = piece - ((solid.rotate({ 0, 0, 90 }, buildHolderHoles(m, m.tallHolderHeight)) >>
            { m.pcbWidth / 2 + m.holderBaseDepth / 2 + m.thickness + m.holderXShift, 0, -(totalHeight - m.baseHeight - m.tallHolderHeight) /
            2 }))
    end

    do
        local needle = solid.cylinder { diameter = m.needleDiameter, height = totalHeight * 2 }
        piece = piece - needleStrip({ m.leftNeedles1[1] - m.pcbWidth / 2, m.leftNeedles1[2] - m.pcbDepth / 2 }, needle, 3)
        piece = piece - needleStrip({ m.leftNeedles2[1] - m.pcbWidth / 2, m.leftNeedles2[2] - m.pcbDepth / 2 }, needle, 3)
        piece = piece - needleStrip({ m.rightNeedles[1] - m.pcbWidth / 2, m.rightNeedles[2] - m.pcbDepth / 2 }, needle, 6)
    end

    return piece
end


local piece = build(measures)
solid.exportToFile(piece, "h2o.scad")

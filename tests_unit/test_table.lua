-- Tests for qpd_table.deep_clone and qpd_table.shallow_clone
package.path = "../?.lua;" .. package.path
local runner   = require "runner"
local qpd_table = require "qpd.table"

local t = runner.new("qpd_table")

-- ---- deep_clone ----

local src = { a = { val = 1 }, b = 2 }
local dc  = qpd_table.deep_clone(src)

dc.a.val = 99
t:eq(src.a.val, 1,  "deep_clone: nested mutation does not affect source")
t:eq(dc.b,      2,  "deep_clone: flat value copied correctly")

dc.b = 100
t:eq(src.b,  2,   "deep_clone: flat mutation does not affect source")

-- deep_clone preserves metatable
local mt  = { __index = { extra = 42 } }
local src2 = setmetatable({ x = 1 }, mt)
local dc2  = qpd_table.deep_clone(src2)
t:eq(getmetatable(dc2), mt, "deep_clone: metatable preserved")

-- ---- shallow_clone ----

local src3  = { a = { val = 1 }, b = 2 }
local sc    = qpd_table.shallow_clone(src3)

-- nested table is SHARED
sc.a.val = 99
t:eq(src3.a.val, 99, "shallow_clone: nested mutation IS visible in source")

-- top-level key is NOT shared
sc.b = 100
t:eq(src3.b, 2, "shallow_clone: flat mutation does NOT affect source")

-- shallow_clone preserves metatable
local src4 = setmetatable({ x = 1 }, mt)
local sc2  = qpd_table.shallow_clone(src4)
t:eq(getmetatable(sc2), mt, "shallow_clone: metatable preserved")

-- ---- sequential array round-trip (the sort-recovery use case) ----

local arr = { "a", "b", "c" }
local copy = qpd_table.shallow_clone(arr)
t:eq(#copy,   3,    "shallow_clone: array length preserved")
t:eq(copy[1], "a",  "shallow_clone: array[1] correct")
t:eq(copy[3], "c",  "shallow_clone: array[3] correct")
-- elements are same references
t:ok(copy[1] == arr[1], "shallow_clone: array elements are same references")

return t:summary()

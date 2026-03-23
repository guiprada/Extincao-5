-- Entry point: run all test files and report overall pass/fail.
-- Run from the tests_unit/ directory:  lua5.4 run_tests.lua

local suites = {
	"test_table",
	"test_ann_neat",
}

local total_failures = 0

for _, suite in ipairs(suites) do
	print("\n=== " .. suite .. " ===")
	local failures = require(suite)
	total_failures = total_failures + (failures or 0)
end

print(string.rep("=", 40))
if total_failures == 0 then
	print("ALL TESTS PASSED")
else
	print(total_failures .. " TOTAL FAILURE(S)")
	os.exit(1)
end

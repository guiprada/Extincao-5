-- Minimal test runner. Returns a context with assertions and a summary.
local runner = {}

function runner.new(suite_name)
	local ctx = { name = suite_name, pass = 0, fail = 0 }

	function ctx:ok(cond, msg)
		if cond then
			self.pass = self.pass + 1
			print("  PASS  " .. msg)
		else
			self.fail = self.fail + 1
			print("  FAIL  " .. msg)
		end
	end

	function ctx:eq(actual, expected, msg)
		local ok = actual == expected
		if not ok then
			msg = msg .. "  (got " .. tostring(actual) .. ", want " .. tostring(expected) .. ")"
		end
		self:ok(ok, msg)
	end

	function ctx:ne(a, b, msg)
		self:ok(a ~= b, msg .. "  (both: " .. tostring(a) .. ")")
	end

	function ctx:summary()
		local total = self.pass + self.fail
		print(string.format("[%s]  %d/%d passed%s",
			self.name, self.pass, total,
			self.fail > 0 and ("  (" .. self.fail .. " FAILED)") or ""))
		return self.fail
	end

	return ctx
end

return runner

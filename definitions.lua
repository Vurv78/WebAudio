---@diagnostic disable:lowercase-global

---@type boolean
SERVER = nil

---@type boolean
CLIENT = nil

E2Helper = {}
E2Lib = {}

wire_expression2_funcs = {}

---@param msg string
---@param level integer?
---@param trace table
---@param can_catch boolean? Default true
function E2Lib.raiseException(msg, level, trace, can_catch)
end

---@param name string
---@param value number
function E2Lib.registerConstant(name, value, literal)

end

---@param num integer
function __e2setcost(num) end

---@param name string
---@param id string
---@param def any
function registerType(name, id, def, ...)

end

---@param name string name of the function
---@param pars string params
---@param rets string ret
---@param func function
---@param cost number?
---@param argnames table?
function registerOperator(name, pars, rets, func, cost, argnames)

end


registerFunction = registerOperator

---@param name string
---@param cb function
function registerCallback(name, cb) end
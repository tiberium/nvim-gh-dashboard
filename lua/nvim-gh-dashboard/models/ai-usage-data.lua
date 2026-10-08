local AiUsageData = {}
AiUsageData.__index = AiUsageData

---@class AiUsageData
---@field additional_budget_credits number
---@field additional_credits number
---@field additional_amount number
---@field included_credits number
---@field included_credits_used number
---@field over_pool_credits number

---@param additional_budget_credits number
---@param additional_credits number
---@param additional_amount number
---@param included_credits number
---@param included_credits_used number
---@param over_pool_credits number
---@return AiUsageData
function AiUsageData.new(
	additional_budget_credits,
	additional_credits,
	additional_amount,
	included_credits,
	included_credits_used,
	over_pool_credits
)
	return setmetatable({
		additional_budget_credits = additional_budget_credits,
		additional_credits = additional_credits,
		additional_amount = additional_amount,
		included_credits = included_credits,
		included_credits_used = included_credits_used,
		over_pool_credits = over_pool_credits,
	}, AiUsageData)
end

return AiUsageData

local M = {}

local ZERO_CREDITS = 0

---@param quota_response table
---@param usage_response table
---@return AiUsageData|nil
function M.extract_usage(quota_response, usage_response)
	local quota = quota_response.quota_snapshots and quota_response.quota_snapshots.premium_interactions
	if not quota then
		return nil
	end

	local additional_credits = ZERO_CREDITS
	local additional_amount = ZERO_CREDITS
	for _, item in ipairs(usage_response.usageItems or {}) do
		additional_credits = additional_credits + (item.netQuantity or ZERO_CREDITS)
		additional_amount = additional_amount + (item.netAmount or ZERO_CREDITS)
	end

	local included_credits = quota.entitlement or ZERO_CREDITS
	return {
		additional_budget_credits = quota.overage_entitlement or ZERO_CREDITS,
		additional_credits = additional_credits,
		additional_amount = additional_amount,
		included_credits = included_credits,
		included_credits_used = math.min(quota.credits_used or ZERO_CREDITS, included_credits),
		over_pool_credits = math.max(ZERO_CREDITS, (quota.credits_used or ZERO_CREDITS) - included_credits),
	}
end

return M

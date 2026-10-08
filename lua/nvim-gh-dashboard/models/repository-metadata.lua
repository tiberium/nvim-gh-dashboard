local RepositoryMetadata = {}
RepositoryMetadata.__index = RepositoryMetadata

---@class RepositoryMetadata
---@field name string
---@field stars string
---@field language string|nil

---@param name string
---@param stars string
---@param language string|nil
---@return RepositoryMetadata
function RepositoryMetadata.new(name, stars, language)
	return setmetatable({
		name = name,
		stars = stars,
		language = language,
	}, RepositoryMetadata)
end

return RepositoryMetadata

local M = {}

function M.fetch_contributions(username)
    local curl = require("plenary.curl")
    local url = string.format("https://github.com/%s?tab=contributions", username)

    local response = curl.get(url, {
        headers = {
            ["x-requested-with"] = "XMLHttpRequest",
        }
    })
    if response.status ~= 200 then
        return nil
    end

    local contributions_matcher = '<tool%-tip.->(.-contribution[s]? on.-)</tool%-tip>'
    local contributions = response.body:gmatch(contributions_matcher)

    local contributions_list = {}
    for contribution in contributions do
        table.insert(contributions_list, contribution)
    end
    return contributions_list
end

return M

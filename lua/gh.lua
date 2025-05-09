local M = {}

function M.fetch_years(username)
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

    local contributions_matcher = '<tool%-tip.->(.-contributions on.-)</tool%-tip>'
    local contributions = response.body:gmatch(contributions_matcher)

    for contribution in contributions do
        print(contribution)
    end

    return contributions
end

return M

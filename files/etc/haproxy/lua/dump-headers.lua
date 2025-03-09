-- selene: allow(undefined_variable)
core.register_service("dump_headers", "http", function(applet) -- luacheck: ignore
  applet:set_status(200)
  applet:add_header("Content-Type", "text/plain")
  applet:add_header("Cache-Control", "no-cache")
  local response = "-----[http headers list]-----\n"
  local headers = applet:get_var("req.hdrs")

  if type(headers) == "string" then
    -- Split the string into individual headers
    local header_list = {}
    for line in headers:gmatch("[^\r\n]+") do
      table.insert(header_list, line)
    end

    -- Sort headers alphabetically
    table.sort(header_list)

    -- Join the sorted headers back into a string
    response = response .. table.concat(header_list, "\r\n") .. "\r\n"
  elseif type(headers) == "table" then
    -- Sort headers alphabetically by their names
    local sorted_keys = {}
    for name, _ in pairs(headers) do
      table.insert(sorted_keys, name)
    end
    table.sort(sorted_keys)

    -- Append sorted headers to the response
    for _, name in ipairs(sorted_keys) do
      local values = headers[name]
      if type(values) == "table" then
        for _, value in ipairs(values) do
          response = response .. name .. ": " .. value .. "\r\n"
        end
      else
        response = response .. name .. ": " .. values .. "\r\n"
      end
    end
  else
    response = "No headers found\r\n"
  end

  applet:start_response()
  applet:send(response)
end)

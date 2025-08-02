-- https://habr.com/ru/articles/531004/
-- https://www.arpalert.org/src/haproxy-lua-api/2.3/index.html
-- selene: allow(undefined_variable)
core.register_action( -- luacheck: ignore
  "get_iso8601_time",
  { "http-req", "tcp-req", "http-res" },
  function(txn)
    txn:set_var(
      "txn.iso8601_time",
      string.format(
        "%s.%03d",
        os.date("!%Y-%m-%dT%H:%M:%S"),
        math.floor(
          -- selene: allow(undefined_variable)
          core.now().usec / 1000 -- luacheck: ignore
        )
      )
    )
  end
)

-- selene: allow(undefined_variable)
core.register_fetches( -- luacheck: ignore
  "iso8601-now",
  function()
    return string.format(
      "%s.%03d",
      os.date("!%Y-%m-%dT%H:%M:%S"),
      math.floor(
        -- selene: allow(undefined_variable)
        core.now().usec / 1000 -- luacheck: ignore
      )
    )
  end
)

-- selene: allow(undefined_variable)
core.register_service("consume_uploading", "http", function(applet) -- luacheck: ignore
  applet:set_status(200)
  applet:add_header("content-type", "text/plain")
  applet:add_header("x-frame-options", "DENY")
  applet:add_header("x-xss-protection", "1; mode=block")
  applet:add_header("x-content-type-options", "nosniff")
  applet:add_header("strict-transport-security", "max-age=63072000; includeSubdomains")
  applet:start_response()
  applet:send("Yummy")
end)

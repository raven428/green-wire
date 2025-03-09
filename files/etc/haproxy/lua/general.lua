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

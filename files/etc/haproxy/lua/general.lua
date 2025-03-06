-- https://habr.com/ru/articles/531004/
-- https://www.arpalert.org/src/haproxy-lua-api/2.3/index.html
core.register_action(
  "get_iso8601_time", { "http-req", "tcp-req", "http-res" }, function(txn)
    txn:set_var(
      "txn.iso8601_time",
      string.format(
        "%s.%03d",
        os.date("!%Y-%m-%dT%H:%M:%S"),
        math.floor(core.now().usec / 1000)
      )
    )
  end
)

core.register_fetches(
  "iso8601-now", function()
   return string.format(
      "%s.%03d",
      os.date("!%Y-%m-%dT%H:%M:%S"),
      math.floor(core.now().usec / 1000)
    )
  end
);

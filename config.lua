-- config.moon

config = require("lapis.config")

config("development", { port=8080, daemon="off"})

config("production", {
  port=80,
  num_workers=4,
  lua_code_cache="off",
  daemon="on"
})


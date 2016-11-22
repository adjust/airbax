use Mix.Config

config :ex_unit,
  assert_receive_timeout: 800,
  refute_receive_timeout: 200

config :airbax,
  project_id:  "project_id",
  project_key: "project_key",
  environment: "test",
  enabled:      true,
  url:         "http://localhost:4004"


# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
use Mix.Config

config :islands_interface,
  ecto_repos: [IslandsInterface.Repo]

# Configures the endpoint
config :islands_interface, IslandsInterfaceWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "4rZzldcJAqd8SjITOtL1xVhnx30kxHz7+x8jq//0ti+ruuVLiJglqiirWWD0xwcc",
  render_errors: [view: IslandsInterfaceWeb.ErrorView, accepts: ~w(html json)],
  pubsub: [name: IslandsInterface.PubSub, adapter: Phoenix.PubSub.PG2],
  live_view: [
    signing_salt: "RXso7qu0jOru9KIp17ipXnHiBYeF6+Wu"
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

config :islands_interface, :pow,
  user: IslandsInterface.Users.User,
  repo: IslandsInterface.Repo

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"

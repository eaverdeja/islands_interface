defmodule IslandsInterface.Repo do
  use Ecto.Repo,
    otp_app: :islands_interface,
    adapter: Ecto.Adapters.Postgres
end

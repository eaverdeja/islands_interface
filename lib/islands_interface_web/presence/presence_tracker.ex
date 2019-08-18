defmodule IslandsInterfaceWeb.PresenceTracker do
  alias Phoenix.Socket.Broadcast
  alias IslandsInterface.GameContext
  alias IslandsInterfaceWeb.Presence

  def track_lobby(%GameContext{current_user: current_user}) do
    {:ok, _} =
      Presence.track(self(), "lobby", current_user, %{
        online_at: inspect(System.system_time(:second))
      })

    :ok
  end

  def track_game(%GameContext{current_game: game, current_user: user}) do
    {:ok, _} =
      Presence.track(self(), get_topic(game), user, %{
        online_at: inspect(System.system_time(:second))
      })

    :ok
  end

  def presence_diff(%Broadcast{event: "presence_diff", topic: "lobby"}, _context) do
    %{online_users: Presence.list("lobby")}
  end

  def presence_diff(%Broadcast{event: "presence_diff"}, %GameContext{current_game: game}) do
    %{online_users: Presence.list(get_topic(game))}
  end

  def users_in_lobby, do: Presence.list("lobby")

  def get_topic(game), do: "game:" <> game
end

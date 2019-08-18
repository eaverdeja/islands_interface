defmodule IslandsInterfaceWeb.Pubsub.Dispatcher do
  alias IslandsInterface.GameContext

  def handle(events, %GameContext{current_game: game, current_user: player_name}) do
    Enum.each(events, &dispatch_event(game, player_name, &1))
  end

  defp dispatch_event(game, player_name, event) do
    case event do
      :subscribe_to_lobby ->
        subscribe_to_lobby()

      :subscribe_to_game ->
        subscribe_to_game(game, player_name)

      :new_game ->
        lobby_broadcast(event)

      :new_player ->
        game_broadcast(game, event, %{"new_player" => player_name})

      :handshake ->
        game_broadcast(game, event)

      {:set_islands = message, params} ->
        game_broadcast_from(game, message, params)

      {:guessed_coordinates = message, params} ->
        game_broadcast_from(game, message, params)

      :game_over ->
        game_broadcast(game, event)

      event ->
        IO.puts("Unknown event: #{inspect(event)}")
    end
  end

  defp subscribe_to_lobby do
    :ok = Phoenix.PubSub.subscribe(IslandsInterface.PubSub, "lobby")
    send(self(), :after_join_lobby)
  end

  defp subscribe_to_game(game, screen_name) do
    :ok = Phoenix.PubSub.subscribe(IslandsInterface.PubSub, get_topic(game))
    send(self(), {:after_join_game, game, screen_name})
  end

  defp game_broadcast(game, message, params \\ %{}) do
    Phoenix.PubSub.broadcast!(
      IslandsInterface.PubSub,
      get_topic(game),
      {message, params}
    )
  end

  defp game_broadcast_from(game, message, params) do
    Phoenix.PubSub.broadcast_from!(
      IslandsInterface.PubSub,
      self(),
      get_topic(game),
      {message, params}
    )
  end

  defp lobby_broadcast(message) do
    Phoenix.PubSub.broadcast!(
      IslandsInterface.PubSub,
      "lobby",
      message
    )
  end

  defp get_topic(name), do: "game:" <> name
end

defmodule IslandsInterfaceWeb.Pubsub.Dispatcher do
  alias IslandsInterface.GameContext

  def handle(%GameContext{} = context, events) do
    Enum.each(events, &dispatch_event(context, &1))

    context
  end

  defp dispatch_event(_context, :subscribe_to_lobby),
    do: subscribe_to_lobby()

  defp dispatch_event(_context, :new_game),
    do: lobby_broadcast(:new_game)

  defp dispatch_event(
         %GameContext{current_game: game},
         :subscribe_to_game
       ),
       do: subscribe_to_game(game)

  defp dispatch_event(
         %GameContext{current_game: game, current_user: player_name},
         :new_player
       ),
       do: game_broadcast(game, :new_player, %{"new_player" => player_name})

  defp dispatch_event(
         %GameContext{current_game: game},
         :handshake
       ),
       do: game_broadcast(game, :handshake)

  defp dispatch_event(
         %GameContext{current_game: game},
         {:set_islands, params}
       ),
       do: game_broadcast_from(game, :set_islands, params)

  defp dispatch_event(
         %GameContext{current_game: game},
         {:guessed_coordinates, params}
       ),
       do: game_broadcast_from(game, :guessed_coordinates, params)

  defp dispatch_event(
         %GameContext{current_game: game},
         :game_over
       ),
       do: game_broadcast(game, :game_over)

  defp dispatch_event(_context, event),
    do: IO.puts("Unknown event: #{inspect(event)}")

  defp subscribe_to_lobby do
    :ok = Phoenix.PubSub.subscribe(IslandsInterface.PubSub, "lobby")
    send(self(), :after_join_lobby)
  end

  defp subscribe_to_game(game) do
    :ok = Phoenix.PubSub.subscribe(IslandsInterface.PubSub, get_topic(game))
    send(self(), :after_join_game)
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

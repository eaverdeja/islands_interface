defmodule IslandsInterfaceWeb.Pubsub.Dispatcher do
  alias IslandsInterface.GameContext

  def handle(events, %GameContext{} = context) do
    player_name = GameContext.get_current_player_name(context)

    Enum.each(events, fn event ->
      case event do
        :subscribe_to_game ->
          subscribe_to_game(context.current_game, player_name)

        :broadcast_game_started ->
          broadcast_game_started()

        :broadcast_join ->
          broadcast_join(context.current_game, player_name)

        event ->
          IO.puts("Unknown event #{inspect(event)}")
      end
    end)
  end

  defp subscribe_to_game(game, screen_name) do
    :ok = Phoenix.PubSub.subscribe(IslandsInterface.PubSub, get_topic(game))
    send(self(), {:after_join_game, game, screen_name})
  end

  defp broadcast_game_started do
    Phoenix.PubSub.broadcast!(
      IslandsInterface.PubSub,
      "lobby",
      :new_game
    )
  end

  defp broadcast_join(game, new_player) do
    Phoenix.PubSub.broadcast!(
      IslandsInterface.PubSub,
      get_topic(game),
      {:new_player, %{"game" => game, "new_player" => new_player}}
    )
  end

  defp get_topic(name), do: "game:" <> name
end

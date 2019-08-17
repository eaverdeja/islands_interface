defmodule IslandsInterface.LobbyHandler do
  alias IslandsEngine.GameSupervisor
  alias IslandsInterface.{GameContext, Screen}

  def handle_event(["new_game"], "", %GameContext{} = context) do
    name = context.current_user

    with {:ok, _pid} <- GameSupervisor.start_game(name) do
      subscribe_to_game(name)
      broadcast_game_started()

      {:ok,
       %{
         player1: name,
         current_player: :player1,
         current_game: name,
         game_state: :pending
       }}
    else
      {:error, {:already_started, _pid}} ->
        {:error, :already_started}
    end
  end

  def handle_event(["join_game"], game, %GameContext{} = context) do
    name = context.current_user
    state_key = build_state_key(name)

    with [] <- :ets.lookup(:interface_state, state_key),
         :ok <- Screen.add_player(game, name) do
      subscribe_to_game(game, name)
      broadcast_join(game, name)

      {:ok,
       %{
         current_player: :player2,
         current_game: game
       }}
    else
      :error ->
        {:error, :no_game}

      [{^state_key, state}] ->
        subscribe_to_game(game, name)
        broadcast_join(game, name)

        {:ok, state}
    end
  end

  defp subscribe_to_game(game), do: subscribe_to_game(game, game)

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

  defp build_state_key(screen_name) do
    :"#{screen_name}_state"
  end
end

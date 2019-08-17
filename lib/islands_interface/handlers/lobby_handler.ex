defmodule IslandsInterface.LobbyHandler do
  alias IslandsEngine.GameSupervisor
  alias IslandsInterface.{GameContext, Screen}

  def handle_event(["new_game"], "", %GameContext{current_user: name}) do
    with {:ok, _pid} <- GameSupervisor.start_game(name) do
      {:ok,
       %{
         player1: name,
         current_player: :player1,
         current_game: name,
         game_state: :pending
       }, [:subscribe_to_game, :broadcast_game_started]}
    else
      {:error, {:already_started, _pid}} ->
        {:error, :already_started}
    end
  end

  def handle_event(["join_game"], game, %GameContext{current_user: name}) do
    state_key = build_state_key(name)

    with [] <- :ets.lookup(:interface_state, state_key),
         :ok <- Screen.add_player(game, name) do
      {:ok,
       %{
         current_game: game,
         current_player: :player2,
         player2: name
       }, [:subscribe_to_game, :broadcast_join]}
    else
      :error ->
        {:error, :no_game}

      [{^state_key, state}] ->
        {:ok, state, [:subscribe_to_game, :broadcast_join]}
    end
  end

  defp build_state_key(screen_name) do
    :"#{screen_name}_state"
  end
end

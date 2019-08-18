defmodule IslandsInterface.LobbyHandler do
  alias IslandsEngine.GameSupervisor
  alias IslandsInterface.{GameContext, Screen}

  def handle_event(["new_game"], "", %GameContext{current_user: name}) do
    with {:ok, _pid} <- GameSupervisor.start_game(name) do
      new_state = %{
        player1: name,
        current_player: :player1,
        current_game: name,
        game_state: :pending
      }

      events = [:subscribe_to_game, :new_game]

      {:ok, new_state, events}
    else
      {:error, {:already_started, _pid}} ->
        {:error, :already_started}
    end
  end

  def handle_event(["join_game"], game, %GameContext{current_user: name}) do
    with :ok <- Screen.add_player(game, name) do
      new_state = %{
        current_game: game,
        current_player: :player2,
        player2: name
      }

      events = [:subscribe_to_game, :new_player]

      {:ok, new_state, events}
    else
      :error ->
        {:error, :no_game}
    end
  end
end

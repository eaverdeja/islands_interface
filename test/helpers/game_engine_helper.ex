defmodule IslandsInterface.GameEngineHelper do
  @valid_states [:initialized, :players_set, :player1_turn, :player2_turn, :game_over]
  @game_name "eaverdeja@gmail.com"

  alias IslandsEngine.{Game, GameSupervisor, Island, Rules}

  def replace_state(game_name, new_state) when new_state in @valid_states do
    game = Game.via_tuple(game_name)

    :sys.replace_state(game, fn state_data ->
      %{state_data | rules: %Rules{state: new_state}}
    end)
  end

  def position_all_islands(game_name \\ @game_name, player \\ :player1) do
    game = Game.via_tuple(game_name)
    coordinates = [{1, 1}, {5, 1}, {7, 3}, {3, 5}, {8, 8}]

    Island.types()
    |> Enum.zip(coordinates)
    |> Enum.map(fn {type, {row, col}} = island_position ->
      Game.position_island(game, player, type, row, col)

      island_position
    end)
  end

  def shutdown_game(game \\ @game_name) do
    case Registry.lookup(Registry.Game, game) do
      [{_pid, _}] -> GameSupervisor.stop_game(game)
      _ -> :ok
    end
  end
end

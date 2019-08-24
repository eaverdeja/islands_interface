defmodule IslandsInterface.GameEngineHelper do
  @game_name "eaverdeja@gmail.com"

  alias IslandsEngine.{Game, GameSupervisor}

  def shutdown_game(game \\ @game_name) do
    case Registry.lookup(Registry.Game, game) do
      [{_pid, _}] -> GameSupervisor.stop_game(game)
      _ -> :ok
    end
  end
end

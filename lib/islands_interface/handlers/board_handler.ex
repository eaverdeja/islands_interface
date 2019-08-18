defmodule IslandsInterface.BoardHandler do
  alias IslandsInterface.{GameContext, Screen}

  def handle_event(["choose_island"], island, %GameContext{
        player_islands: player_islands
      }) do
    chosen_island = String.to_existing_atom(island)

    new_state = %{
      player_islands: Screen.choose_island(player_islands, chosen_island),
      current_island: chosen_island
    }

    {:ok, new_state}
  end

  def handle_event(
        ["position_island"],
        <<row, col>>,
        %GameContext{
          current_game: game,
          current_player: current_player,
          current_island: island,
          player_islands: player_islands
        }
      ) do
    with {:ok, new_board} <- Screen.position_island(game, current_player, island, row, col) do
      player_islands = put_in(player_islands, [island, :state], :positioned)

      new_state = %{
        player_islands: player_islands,
        board: new_board,
        current_island: nil
      }

      {:ok, new_state}
    else
      {:error, reason} ->
        {:error, reason}
    end
  end

  def handle_event(["set_islands"], _, %GameContext{
        current_game: game,
        current_player: player,
        player_islands: player_islands
      }) do
    case Screen.set_islands(game, player) do
      {:ok, new_board} ->
        player_islands =
          Enum.reduce(player_islands, %{}, fn {type, info}, player_islands ->
            Map.put_new(player_islands, type, put_in(info.state, :set))
          end)

        new_state = %{
          player_islands: player_islands,
          board: new_board
        }

        events = [{:set_islands, %{"player" => player}}]

        {:ok, new_state, events}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def handle_event(["guess_coordinate"], <<row, col>>, %GameContext{
        player1: game,
        current_player: current_player,
        opponent_board: opponent_board
      }) do
    case Screen.guess_coordinate(game, current_player, row, col) do
      {:ok, :miss} ->
        new_state = %{
          opponent_board: Screen.change_tile(opponent_board, row, col, :miss)
        }

        {:ok, new_state}

      {:ok, :hit, :win} ->
        new_state = %{
          opponent_board: Screen.change_tile(opponent_board, row, col, :forest),
          game_state: :game_over,
          won_game: :winner
        }

        events = [
          {:guessed_coordinates,
           %{
             "row" => row,
             "col" => col
           }},
          :game_over
        ]

        {:ok, new_state, events}

      {:ok, :hit, _forested} ->
        new_state = %{
          opponent_board: Screen.change_tile(opponent_board, row, col, :forest)
        }

        events = [
          {:guessed_coordinates,
           %{
             "row" => row,
             "col" => col
           }}
        ]

        {:ok, new_state, events}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def handle_event(["debug_position_islands"], "", %GameContext{
        player1: game,
        current_player: current_player,
        player_islands: player_islands
      }) do
    with %{board: new_board, player_islands: islands} <-
           debug_position_islands(game, current_player, player_islands) do
      new_state = %{
        player_islands: islands,
        board: new_board,
        current_island: nil
      }

      {:ok, new_state}
    else
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp debug_position_islands(game, current_player, player_islands) do
    IslandsEngine.Island.types()
    |> Enum.zip([{1, 1}, {5, 1}, {7, 3}, {3, 5}, {8, 8}])
    |> Enum.reduce(%{player_islands: player_islands, board: nil}, fn {island, {row, col}}, acc ->
      case Screen.position_island(game, current_player, island, row, col) do
        {:ok, new_board} ->
          islands = put_in(acc.player_islands, [island, :state], :positioned)

          %{
            acc
            | player_islands: islands,
              board: new_board
          }

        {:error, reason} ->
          {:error, reason}
      end
    end)
  end
end

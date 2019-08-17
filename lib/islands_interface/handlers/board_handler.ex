defmodule IslandsInterface.BoardHandler do
  alias IslandsInterface.{GameContext, Screen}

  def handle_event(["choose_island"], island, %GameContext{
        player_islands: player_islands
      }) do
    chosen_island = String.to_existing_atom(island)

    {:ok,
     %{
       player_islands: Screen.choose_island(player_islands, chosen_island),
       current_island: chosen_island
     }}
  end

  def handle_event(
        ["position_island"],
        <<row, col>>,
        %GameContext{
          player1: game,
          current_player: current_player,
          current_island: island,
          player_islands: player_islands
        }
      ) do
    with {:ok, new_board} <- Screen.position_island(game, current_player, island, row, col) do
      player_islands = put_in(player_islands, [island, :state], :positioned)

      {:ok,
       %{
         player_islands: player_islands,
         board: new_board,
         current_island: nil
       }}
    else
      {:error, reason} ->
        {:error, reason}
    end
  end

  def handle_event(["set_islands"], _, %GameContext{
        player1: game,
        current_player: player,
        player_islands: player_islands
      }) do
    case Screen.set_islands(game, player) do
      {:ok, new_board} ->
        do_broadcast(game, :set_islands, %{"player" => player})

        player_islands =
          Enum.reduce(player_islands, %{}, fn {type, info}, player_islands ->
            Map.put_new(player_islands, type, put_in(info.state, :set))
          end)

        {:ok,
         %{
           player_islands: player_islands,
           board: new_board
         }}

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
        {:ok,
         %{
           opponent_board: Screen.change_tile(opponent_board, row, col, :miss)
         }}

      {:ok, :hit, :win} ->
        do_broadcast(game, :game_over, %{})

        do_broadcast(game, :guessed_coordinates, %{
          "row" => row,
          "col" => col
        })

        {:ok,
         %{
           opponent_board: Screen.change_tile(opponent_board, row, col, :forest),
           game_state: :game_over,
           won_game: :winner
         }}

      {:ok, :hit, _forested} ->
        do_broadcast(game, :guessed_coordinates, %{
          "row" => row,
          "col" => col
        })

        {:ok,
         %{
           opponent_board: Screen.change_tile(opponent_board, row, col, :forest)
         }}

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
      {:ok,
       %{
         player_islands: islands,
         board: new_board,
         current_island: nil
       }}
    else
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp do_broadcast(game, message, params) do
    Phoenix.PubSub.broadcast_from!(
      IslandsInterface.PubSub,
      self(),
      "game:" <> game,
      {message, params}
    )
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

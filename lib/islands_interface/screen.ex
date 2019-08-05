defmodule IslandsInterface.Screen do
  alias IslandsEngine.{Coordinate, Game, Island}

  def init_board() do
    for row <- 1..10 do
      for col <- 1..10 do
        {:ok, coordinate} = Coordinate.new(row, col)
        {:sea, coordinate}
      end
    end
    |> List.flatten()
    |> Enum.reduce(%{}, fn {type, coordinate}, board ->
      board =
        unless board[coordinate.row] do
          put_in(board[coordinate.row], %{})
        else
          board
        end

      put_in(board[coordinate.row][coordinate.col], {type, coordinate})
    end)
  end

  def init_player_islands() do
    Island.types()
    |> Enum.map(fn island ->
      case island do
        :square -> %{name: "Square"}
        :atoll -> %{name: "Atoll"}
        :dot -> %{name: "Dot"}
        :l_shape -> %{name: "L-shape"}
        :s_shape -> %{name: "S-shape"}
      end
      |> Map.put(:state, :_)
      |> Map.put(:type, island)
    end)
    |> Enum.reduce(%{}, fn island, acc ->
      Map.put(acc, island.type, island)
    end)
  end

  def add_player(game, name) do
    game
    |> via()
    |> Game.add_player(name)
  end

  def choose_island(player_islands, chosen_island) do
    Enum.map(player_islands, fn {island, info} ->
      cond do
        island == chosen_island -> {island, put_in(info.state, :positioning)}
        info.state == :positioned -> {island, info}
        true -> {island, put_in(info.state, :_)}
      end
    end)
    |> Map.new()
  end

  def position_island(game, current_player, island, row, col) do
    case Game.position_island(via(game), current_player, island, row, col) do
      {:ok, new_board} -> {:ok, update_board(new_board)}
      {:error, reason} -> {:error, reason}
      :error -> {:error, :error}
    end
  end

  def set_islands(game, player) do
    case Game.set_islands(via(game), player) do
      {:ok, new_board} -> {:ok, update_board(new_board)}
      {:error, reason} -> {:error, reason}
      :error -> {:error, :error}
    end
  end

  def guess_coordinate(game, current_player, row, col) do
    case Game.guess_coordinate(via(game), current_player, row, col) do
      {:miss, :none, :no_win, _new_board} -> {:ok, :miss}
      {:hit, forested, :no_win, new_board} -> {:ok, update_board(new_board, true), forested}
      {:hit, _forested, :win, new_board} -> {:ok, update_board(new_board, true), :win}
      :error -> {:error, :error}
    end
  end

  @spec forest_tile(keyword | map, any, any) :: keyword | map
  def forest_tile(board, row, col) do
    put_in(board[row][col], {:forest, Coordinate.new(row, col)})
  end

  defp via(game), do: Game.via_tuple(game)

  defp update_board(new_board, opponent_board \\ false) do
    unless(opponent_board) do
      Enum.reduce(new_board, init_board(), &update_coordinates(&1, &2))
    else
      Enum.reduce(new_board, init_board(), &update_opponent_coordinates(&1, &2))
    end
  end

  defp update_coordinates(
         {_island, %{coordinates: coordinates, hit_coordinates: hit_coordinates}},
         board
       ) do
    board
    |> do_coordinate_update(coordinates)
    |> do_coordinate_update(hit_coordinates)
  end

  defp update_opponent_coordinates(
         {_island, %{hit_coordinates: hit_coordinates}},
         board
       ) do
    board
    |> do_coordinate_update(hit_coordinates)
  end

  defp do_coordinate_update(board, coordinates) do
    coordinates
    |> Enum.reduce(board, fn %Coordinate{row: row, col: col} = coordinate, board ->
      put_in(board[row][col], {:island, coordinate})
    end)
  end
end

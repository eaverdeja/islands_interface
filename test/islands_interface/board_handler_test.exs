defmodule IslandsInterface.BoardHandlerTest do
  use ExUnit.Case
  import Mox

  alias IslandsInterface.{GameContext, BoardHandler}
  alias IslandsEngine.{Coordinate}

  @game_name "eaverdeja@gmail.com"
  @player_islands %{
    atoll: %{name: "Atoll", state: :_, type: :atoll},
    dot: %{name: "Dot", state: :_, type: :dot},
    l_shape: %{name: "L-shape", state: :_, type: :l_shape},
    s_shape: %{name: "S-shape", state: :_, type: :s_shape},
    square: %{name: "Square", state: :_, type: :square}
  }

  setup do
    IslandsInterface.GameMock
    |> expect(:via_tuple, fn game -> {:via, Registry, {Registry.Game, game}} end)

    [game_context: GameContext.new(%{current_game: @game_name})]
  end

  describe "Positioning islands" do
    test "selects an island for positioning", %{game_context: context} do
      context = %{
        context
        | current_user: @game_name,
          player_islands: @player_islands
      }

      island = "dot"

      state = %{
        player_islands: %{@player_islands | dot: %{@player_islands.dot | state: :positioning}},
        current_island: String.to_existing_atom(island)
      }

      assert {:ok, ^state} = BoardHandler.handle_event(["choose_island"], island, context)
    end

    test "positions the current island in the given coordinates on the board", %{
      game_context: context
    } do
      context = %{
        context
        | current_user: @game_name,
          current_player: :player1,
          player_islands: @player_islands,
          current_island: :dot
      }

      row = 1
      col = 1
      coordinates = <<row, col>>

      player_islands = %{@player_islands | dot: %{@player_islands.dot | state: :positioned}}

      IslandsInterface.GameMock
      |> expect(:position_island, fn _game, _current_player, island_type, row, col ->
        {:ok, coordinate} = IslandsEngine.Coordinate.new(row, col)
        {:ok, island} = IslandsEngine.Island.new(island_type, coordinate)

        {:ok, Map.put_new(%{}, island_type, island)}
      end)

      assert {:ok, %{board: board, player_islands: ^player_islands, current_island: nil}} =
               BoardHandler.handle_event(["position_island"], coordinates, context)

      tile = board[row][col]

      assert ^tile = {:island, %Coordinate{row: row, col: col}}
    end

    test "indicates a given player has finished setting his islands", %{
      game_context: context
    } do
      context = %{
        context
        | current_user: @game_name,
          current_player: :player1,
          player_islands: @player_islands,
          current_island: :dot
      }

      player_islands =
        @player_islands
        |> Enum.map(fn {name, island} ->
          {name, %{island | state: :set}}
        end)
        |> Enum.into(%{})

      events = [set_islands: %{"player" => :player1}]

      IslandsInterface.GameMock
      |> expect(:set_islands, fn _game, _current_player -> {:ok, %{}} end)

      assert {:ok, %{board: board, player_islands: ^player_islands}, ^events} =
               BoardHandler.handle_event(["set_islands"], "", context)
    end
  end

  describe "guessing coordinates" do
    test "updates the board after hitting a coordinate", %{
      game_context: context
    } do
      col = row = 1
      opponent_board = %{1 => %{1 => %{}}}

      context = %{
        context
        | opponent_board: opponent_board
      }

      events = [
        {:guessed_coordinates,
         %{
           "row" => row,
           "col" => col
         }}
      ]

      {:ok, coordinate} = IslandsEngine.Coordinate.new(row, col)

      new_board =
        opponent_board
        |> put_in([row, col], {:forest, {:ok, coordinate}})

      new_state = %{opponent_board: new_board}

      IslandsInterface.GameMock
      |> expect(:guess_coordinate, fn _game, _current_player, _row, _col ->
        {:hit, opponent_board, :no_win}
      end)

      assert {:ok, ^new_state, ^events} =
               BoardHandler.handle_event(["guess_coordinate"], <<row, col>>, context)
    end
  end
end

defmodule IslandsInterface.BoardHandlerTest do
  use ExUnit.Case

  alias IslandsInterface.{GameContext, BoardHandler, GameEngineHelper}
  alias IslandsEngine.{Coordinate, GameSupervisor}

  @game_name "eaverdeja@gmail.com"
  @player_islands %{
    atoll: %{name: "Atoll", state: :_, type: :atoll},
    dot: %{name: "Dot", state: :_, type: :dot},
    l_shape: %{name: "L-shape", state: :_, type: :l_shape},
    s_shape: %{name: "S-shape", state: :_, type: :s_shape},
    square: %{name: "Square", state: :_, type: :square}
  }

  setup do
    on_exit(fn -> GameEngineHelper.shutdown_game() end)

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

      {:ok, _pid} = GameSupervisor.start_game(@game_name)
      GameEngineHelper.replace_state(@game_name, :players_set)
      row = 1
      col = 1
      coordinates = <<row, col>>

      player_islands = %{@player_islands | dot: %{@player_islands.dot | state: :positioned}}

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

      {:ok, _pid} = GameSupervisor.start_game(@game_name)
      GameEngineHelper.replace_state(@game_name, :players_set)
      island_positions = GameEngineHelper.position_all_islands()

      player_islands =
        @player_islands
        |> Enum.map(fn {name, island} ->
          {name, %{island | state: :set}}
        end)
        |> Enum.into(%{})

      events = [set_islands: %{"player" => :player1}]

      assert {:ok, %{board: board, player_islands: ^player_islands}, ^events} =
               BoardHandler.handle_event(["set_islands"], "", context)

      Enum.each(island_positions, fn {type, {row, col}} ->
        case type do
          :s_shape ->
            row = row + 1
            tile = board[row][col]
            assert ^tile = {:island, %Coordinate{row: row, col: col}}

          _ ->
            tile = board[row][col]
            assert ^tile = {:island, %Coordinate{row: row, col: col}}
        end
      end)
    end
  end
end

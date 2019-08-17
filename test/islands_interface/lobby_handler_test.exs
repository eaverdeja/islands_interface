defmodule IslandsInterface.LobbyHandlerTest do
  use ExUnit.Case

  alias IslandsInterface.{GameContext, LobbyHandler}
  alias IslandsEngine.GameSupervisor

  @game_name "eaverdeja@gmail.com"

  setup do
    on_exit(fn -> shutdown_game() end)

    [game_context: GameContext.new(%{current_game: @game_name})]
  end

  describe "new games" do
    test "handles new games", %{game_context: context} do
      context = %{context | current_user: @game_name}

      state = %{
        current_game: @game_name,
        player1: @game_name,
        current_player: :player1,
        game_state: :pending
      }

      events = [:subscribe_to_game, :broadcast_game_started]

      assert {:ok, ^state, ^events} = LobbyHandler.handle_event(["new_game"], "", context)
    end

    test "Returns an error if there's already a game with the given name", %{
      game_context: context
    } do
      context = %{context | current_user: @game_name}
      {:ok, _pid} = GameSupervisor.start_game(@game_name)

      assert {:error, :already_started} = LobbyHandler.handle_event(["new_game"], "", context)
    end
  end

  describe "joining games" do
    test "handles a new player joining an existing game", %{game_context: context} do
      name = "madmax@gmail.com"
      context = %{context | current_user: name}
      {:ok, _pid} = GameSupervisor.start_game(@game_name)

      state = %{
        current_game: @game_name,
        current_player: :player2,
        player2: name
      }

      events = [:subscribe_to_game, :broadcast_join]

      assert {:ok, ^state, ^events} =
               LobbyHandler.handle_event(["join_game"], @game_name, context)
    end

    test "returns an error if a player tries to join a non-existing game", %{
      game_context: context
    } do
      name = "madmax@gmail.com"
      context = %{context | current_user: name}

      assert {:error, :no_game} = LobbyHandler.handle_event(["join_game"], @game_name, context)
    end
  end

  defp shutdown_game do
    case Registry.lookup(Registry.Game, @game_name) do
      [{_pid, _}] -> GameSupervisor.stop_game(@game_name)
      _ -> :ok
    end
  end
end

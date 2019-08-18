defmodule IslandsInterfaceWeb.MessageHandler do
  alias IslandsEngine.{Game, GameSupervisor}
  alias IslandsInterface.{GameContext, Screen}
  alias IslandsInterfaceWeb.PresenceTracker
  alias IslandsInterfaceWeb.Pubsub.Dispatcher

  def handle(:count_games, %GameContext{}) do
    games_running = Enum.count(GameSupervisor.children())

    %{games_running: games_running}
  end

  def handle(:clean_error_message, %GameContext{}) do
    %{error_message: nil}
  end

  def handle(:after_join_lobby, %GameContext{} = context) do
    :ok = PresenceTracker.track_lobby(context)

    %{open_games: get_open_games()}
  end

  def handle(:after_join_game, %GameContext{} = context) do
    :ok = PresenceTracker.track_game(context)

    state_key = build_state_key(context.current_user)
    :ets.insert(:interface_state, {state_key, context})
  end

  def handle(:new_game, %GameContext{}) do
    %{open_games: get_open_games()}
  end

  def handle({:new_player, %{"new_player" => new_player}}, %GameContext{} = context) do
    _ = Dispatcher.handle(context, [:handshake])

    %{player2: new_player, game_state: :setting_islands}
  end

  def handle({:handshake, %{}}, %GameContext{} = context) do
    %{player1: context.current_game}
  end

  def handle({:set_islands, %{"player" => player}}, %GameContext{game_state: game_state}) do
    game_state =
      case game_state do
        :setting_islands -> :"#{player}_set"
        _ -> :game_on
      end

    %{game_state: game_state}
  end

  def handle(
        {:guessed_coordinates, %{"row" => row, "col" => col}},
        %GameContext{board: board}
      ) do
    %{board: Screen.change_tile(board, row, col, :forest)}
  end

  def handle({:game_over, _}, %GameContext{}) do
    %{won_game: :loser}
  end

  defp get_open_games do
    PresenceTracker.users_in_lobby()
    |> Map.keys()
    |> Enum.filter(fn user ->
      Enum.any?(GameSupervisor.children(), fn {_, pid, _, _} ->
        case Registry.lookup(Registry.Game, user) do
          [{^pid, _}] -> true
          _ -> false
        end
      end)
    end)
  end

  defp build_state_key(screen_name) do
    :"#{screen_name}_state"
  end
end

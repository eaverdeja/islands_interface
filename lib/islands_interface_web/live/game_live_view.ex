defmodule IslandsInterfaceWeb.GameLiveView do
  use Phoenix.LiveView

  alias IslandsEngine.GameSupervisor
  alias IslandsInterface.Screen

  @initial_state %{
    games_running: 0,
    game_already_started: false,
    player1: nil,
    player2: nil,
    player_islands: %{},
    current_island: nil,
    board: %{},
    error_message: nil
  }

  def render(assigns) do
    Phoenix.View.render(IslandsInterfaceWeb.GameView, "index.html", assigns)
  end

  def mount(_session, socket) do
    {:ok, _} = :timer.send_interval(1000, self(), :count_games)

    socket =
      case :ets.lookup(:interface_state, :state) do
        [] ->
          assign(socket, @initial_state)
          |> assign(:player_islands, Screen.init_player_islands())
          |> assign(:board, Screen.init_board())

        [state: state] ->
          state
          |> Enum.reduce(socket, fn {key, value}, socket ->
            assign(socket, key, value)
          end)
      end

    {:ok, socket}
  end

  def handle_info(:count_games, socket) do
    games_running = Enum.count(GameSupervisor.children())
    {:noreply, assign(socket, :games_running, games_running)}
  end

  def handle_info(:clean_error_message, socket) do
    {:noreply, assign(socket, :error_message, nil)}
  end

  def handle_info({:new_player, %{"game" => _, "new_player" => new_player}}, socket) do
    {:noreply, assign(socket, :player2, new_player)}
  end

  def handle_event("new_game", %{"name" => name}, socket) do
    case GameSupervisor.start_game(name) do
      {:ok, _pid} ->
        subscribe_to_game(name)
        socket = assign(socket, :player1, name)
        :ets.insert(:interface_state, {:state, socket.assigns})

        {:noreply, socket}

      {:error, {:already_started, _pid}} ->
        {:noreply, assign_error_message(socket, :already_started)}
    end
  end

  def handle_event("join_game", %{"game" => game, "name" => name}, socket) do
    game
    |> Screen.add_player(name)
    |> case do
      :ok ->
        subscribe_to_game(name)
        broadcast_join(game, name)

        {:noreply, socket}

      :error ->
        {:noreply, assign_error_message(socket, :no_game)}
    end
  end

  def handle_event("choose_island", island, socket) do
    chosen_island = String.to_existing_atom(island)

    player_islands = socket.assigns.player_islands
    player_islands = Screen.choose_island(player_islands, chosen_island)

    socket =
      socket
      |> assign(:player_islands, player_islands)
      |> assign(:current_island, chosen_island)

    {:noreply, socket}
  end

  def handle_event("position_island", <<row, col>>, socket) do
    island = socket.assigns.current_island
    player = socket.assigns.player1

    socket =
      case Screen.position_island(player, island, row, col) do
        {:ok, new_board} ->
          player_islands =
            socket.assigns.player_islands
            |> put_in([island, :state], :positioned)

          socket
          |> assign(:player_islands, player_islands)
          |> assign(:board, new_board)

        {:error, reason} ->
          assign_error_message(socket, reason)
      end
      |> assign(:current_island, island)

    {:noreply, socket}
  end

  def terminate(reason, socket) do
    IO.inspect(reason, label: "BOOM")
    :ets.insert(:interface_state, {:state, socket.assigns})
  end

  defp subscribe_to_game(game) do
    :ok = Phoenix.PubSub.subscribe(IslandsInterface.PubSub, "game:" <> game)
  end

  defp broadcast_join(game, new_player) do
    Phoenix.PubSub.broadcast!(
      IslandsInterface.PubSub,
      "game:" <> game,
      {:new_player, %{"game" => game, "new_player" => new_player}}
    )
  end

  defp assign_error_message(socket, reason) do
    message = get_error_message(reason)
    {:ok, _} = :timer.send_after(@error_message_timeout, :clean_error_message)

    assign(socket, :error_message, message)
  end

  defp get_error_message(reason) do
    case Map.has_key?(@error_messages, reason) do
      true ->
        @error_messages[reason]

      false ->
        IO.inspect(reason, label: "Unknown error")
        "Unknown error"
    end
  end
end

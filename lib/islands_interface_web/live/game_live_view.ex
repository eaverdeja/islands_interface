defmodule IslandsInterfaceWeb.GameLiveView do
  use Phoenix.LiveView

  alias IslandsEngine.GameSupervisor
  alias IslandsInterface.Screen
  alias IslandsInterfaceWeb.Presence
  alias Phoenix.Socket.Broadcast

  import IslandsInterfaceWeb.LiveErrorHelper, only: [assign_error_message: 2]

  @initial_state %{
    games_running: 0,
    game_already_started: false,
    player1: nil,
    player2: nil,
    player_islands: %{},
    current_island: nil,
    board: %{},
    opponent_board: %{},
    error_message: nil,
    current_player: nil,
    game_state: nil
  }

  def render(assigns) do
    Phoenix.View.render(IslandsInterfaceWeb.GameView, "index.html", assigns)
  end

  def mount(_session, socket) do
    {:ok, _} = :timer.send_interval(1000, self(), :count_games)

    socket =
      assign(socket, @initial_state)
      |> assign(:player_islands, Screen.init_player_islands())
      |> assign(:board, Screen.init_board())
      |> assign(:opponent_board, Screen.init_board())

    {:ok, socket}
  end

  def handle_info(:count_games, socket) do
    games_running = Enum.count(GameSupervisor.children())
    {:noreply, assign(socket, :games_running, games_running)}
  end

  def handle_info(:clean_error_message, socket) do
    {:noreply, assign(socket, :error_message, nil)}
  end

  def handle_info({:after_join, game, screen_name}, socket) do
    {:ok, _} =
      Presence.track(self(), get_topic(game), screen_name, %{
        online_at: inspect(System.system_time(:second))
      })

    state_key = build_state_key(screen_name)
    :ets.insert(:interface_state, {state_key, socket.assigns})

    {:noreply, socket}
  end

  def handle_info(%Broadcast{event: "presence_diff"}, socket) do
    {:noreply, fetch(socket)}
  end

  def handle_info({:new_player, %{"game" => game, "new_player" => new_player}}, socket) do
    broadcast_handshake(game)

    socket =
      socket
      |> assign(:player2, new_player)
      |> assign(:game_state, :setting_islands)

    {:noreply, socket}
  end

  def handle_info({:handshake, %{"game" => game}}, socket) do
    {:noreply, assign(socket, :player1, game)}
  end

  def handle_info({:update_child_assigns, assigns}, socket) do
    socket =
      Enum.reduce(assigns, socket, fn {key, value}, socket ->
        assign(socket, key, value)
      end)

    {:noreply, socket}
  end

  def handle_info({:set_islands, %{"player" => player}}, socket) do
    game_state =
      case socket.assigns.game_state do
        :setting_islands -> :"#{player}_set"
        _ -> :game_on
      end

    {:noreply, assign(socket, :game_state, game_state)}
  end

  def handle_info({:guessed_coordinates, %{"row" => row, "col" => col}}, socket) do
    board = Screen.forest_tile(socket.assigns.board, row, col)

    {:noreply, assign(socket, :board, board)}
  end

  def handle_event("new_game", %{"name" => name}, socket) do
    state_key = build_state_key(name)

    socket =
      with [] <- :ets.lookup(:interface_state, state_key),
           {:ok, _pid} <- GameSupervisor.start_game(name) do
        subscribe_to_game(name)

        socket =
          socket
          |> assign(:player1, name)
          |> assign(:current_player, :player1)
          |> assign(:game_state, :pending)

        socket
      else
        {:error, {:already_started, _pid}} ->
          assign_error_message(socket, :already_started)

        [{^state_key, state}] ->
          subscribe_to_game(name)
          assign_state(socket, state)
      end

    {:noreply, socket}
  end

  def handle_event("join_game", %{"game" => game, "name" => name}, socket) do
    state_key = build_state_key(name)

    socket =
      with [] <- :ets.lookup(:interface_state, state_key),
           :ok <- Screen.add_player(game, name) do
        subscribe_to_game(game, name)
        broadcast_join(game, name)

        assign(socket, :current_player, :player2)
      else
        :error ->
          assign_error_message(socket, :no_game)

        [{^state_key, state}] ->
          subscribe_to_game(game, name)
          assign_state(socket, state)
      end

    {:noreply, socket}
  end

  def terminate(reason, socket) do
    IO.inspect(reason, label: "BOOM")
    current_player = socket.assigns.current_player

    if current_player do
      state_key =
        case current_player do
          :player1 -> socket.assigns.player1
          :player2 -> socket.assigns.player2
        end
        |> build_state_key()

      :ets.insert(:interface_state, {state_key, socket.assigns})
    end
  end

  defp assign_state(socket, state) do
    IO.inspect(state, label: "Reassigning state")

    state
    |> Enum.reduce(socket, fn {key, value}, socket ->
      assign(socket, key, value)
    end)
  end

  defp fetch(socket) do
    game = socket.assigns.player1

    if game do
      assign(socket, %{
        online_users: Presence.list(get_topic(game))
      })
    end
  end

  defp get_topic(name), do: "game:" <> name

  defp subscribe_to_game(game), do: subscribe_to_game(game, game)

  defp subscribe_to_game(game, screen_name) do
    :ok = Phoenix.PubSub.subscribe(IslandsInterface.PubSub, get_topic(game))
    send(self(), {:after_join, game, screen_name})
  end

  defp broadcast_join(game, new_player) do
    Phoenix.PubSub.broadcast!(
      IslandsInterface.PubSub,
      get_topic(game),
      {:new_player, %{"game" => game, "new_player" => new_player}}
    )
  end

  defp broadcast_handshake(game) do
    Phoenix.PubSub.broadcast_from!(
      IslandsInterface.PubSub,
      self(),
      get_topic(game),
      {:handshake, %{"game" => game}}
    )
  end

  defp build_state_key(screen_name) do
    :"#{screen_name}_state"
  end
end

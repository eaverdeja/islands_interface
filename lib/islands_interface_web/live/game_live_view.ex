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
    current_user: nil,
    won_game: nil,
    game_state: nil,
    game_log: nil,
    open_games: [],
    current_game: nil
  }

  def render(assigns) do
    Phoenix.View.render(IslandsInterfaceWeb.GameView, "index.html", assigns)
  end

  def mount(%{"current_user" => %{email: email}}, socket) do
    state_key = build_state_key(email)

    {:ok, _} = :timer.send_interval(3000, self(), :count_games)

    socket =
      with [] <- :ets.lookup(:interface_state, state_key) do
        subscribe_to_lobby()

        socket
        |> assign(@initial_state)
        |> assign(:player_islands, Screen.init_player_islands())
        |> assign(:board, Screen.init_board())
        |> assign(:opponent_board, Screen.init_board())
      else
        [{^state_key, state}] ->
          case state.game_state do
            :pending ->
              subscribe_to_lobby()
              subscribe_to_game(state.current_game, state.current_user)

            nil ->
              subscribe_to_lobby()

            _ ->
              subscribe_to_game(state.current_game, state.current_user)
          end

          assign_state(socket, state)
      end
      |> assign(:current_user, email)

    {:ok, socket}
  end

  def handle_info(:count_games, socket) do
    games_running = Enum.count(GameSupervisor.children())
    player = socket.assigns.player1

    game_log =
      if games_running > 0 && player do
        player
        |> IslandsEngine.Game.via_tuple()
        |> :sys.get_state()
        |> inspect(pretty: true)
      else
        "..."
      end

    socket =
      socket
      |> assign(:games_running, games_running)
      |> assign(:game_log, game_log)

    {:noreply, socket}
  end

  def handle_info(:clean_error_message, socket) do
    {:noreply, assign(socket, :error_message, nil)}
  end

  def handle_info(:after_join_lobby, socket) do
    {:ok, _} =
      Presence.track(self(), "lobby", socket.assigns.current_user, %{
        online_at: inspect(System.system_time(:second))
      })

    {:noreply, assign(socket, :open_games, get_open_games())}
  end

  def handle_info({:after_join_game, game, screen_name}, socket) do
    {:ok, _} =
      Presence.track(self(), get_topic(game), screen_name, %{
        online_at: inspect(System.system_time(:second))
      })

    state_key = build_state_key(screen_name)
    :ets.insert(:interface_state, {state_key, socket.assigns})

    {:noreply, socket}
  end

  def handle_info(%Broadcast{event: "presence_diff", topic: "lobby"}, socket) do
    socket =
      socket
      |> assign(%{
        online_users: Presence.list("lobby")
      })
      |> assign(:open_games, get_open_games())

    {:noreply, socket}
  end

  def handle_info(%Broadcast{event: "presence_diff"}, socket) do
    {:noreply, fetch(socket)}
  end

  def handle_info(:new_game, socket) do
    {:noreply, assign(socket, :open_games, get_open_games())}
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
    socket = update(socket, :board, &Screen.change_tile(&1, row, col, :forest))

    {:noreply, socket}
  end

  def handle_info({:game_over, _}, socket) do
    socket = assign(socket, :won_game, :loser)

    {:noreply, socket}
  end

  def handle_event("new_game", "", socket) do
    name = socket.assigns.current_user

    socket =
      with {:ok, _pid} <- GameSupervisor.start_game(name) do
        subscribe_to_game(name)
        broadcast_game_started()

        socket
        |> assign(:player1, name)
        |> assign(:current_player, :player1)
        |> assign(:current_game, name)
        |> assign(:game_state, :pending)
      else
        {:error, {:already_started, _pid}} ->
          assign_error_message(socket, :already_started)
      end

    {:noreply, socket}
  end

  def handle_event("join_game", game, socket) do
    name = socket.assigns.current_user
    state_key = build_state_key(name)

    socket =
      with [] <- :ets.lookup(:interface_state, state_key),
           :ok <- Screen.add_player(game, name) do
        subscribe_to_game(game, name)
        broadcast_join(game, name)

        socket
        |> assign(:current_player, :player2)
        |> assign(:current_game, game)
      else
        :error ->
          assign_error_message(socket, :no_game)

        [{^state_key, state}] ->
          subscribe_to_game(game, name)
          broadcast_join(game, name)
          assign_state(socket, state)
      end

    {:noreply, socket}
  end

  def terminate(reason, socket) do
    IO.inspect(reason, label: "BOOM")
    current_player = socket.assigns.current_player

    if current_player do
      state_key =
        current_player
        |> case do
          :player1 -> socket.assigns.player1
          :player2 -> socket.assigns.player2
        end
        |> build_state_key()

      :ets.insert(:interface_state, {state_key, socket.assigns})
    end
  end

  defp assign_state(socket, state) do
    Enum.reduce(state, socket, fn {key, value}, socket ->
      assign(socket, key, value)
    end)
  end

  defp fetch(socket) do
    game = socket.assigns.current_game

    if game do
      assign(socket, %{
        online_users: Presence.list(get_topic(game))
      })
    end
  end

  defp get_topic(name), do: "game:" <> name

  defp subscribe_to_lobby do
    :ok = Phoenix.PubSub.subscribe(IslandsInterface.PubSub, "lobby")
    send(self(), :after_join_lobby)
  end

  defp get_open_games do
    Presence.list("lobby")
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

  defp subscribe_to_game(game), do: subscribe_to_game(game, game)

  defp subscribe_to_game(game, screen_name) do
    :ok = Phoenix.PubSub.subscribe(IslandsInterface.PubSub, get_topic(game))
    send(self(), {:after_join_game, game, screen_name})
  end

  defp broadcast_game_started do
    Phoenix.PubSub.broadcast!(
      IslandsInterface.PubSub,
      "lobby",
      :new_game
    )
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

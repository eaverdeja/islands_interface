defmodule IslandsInterfaceWeb.GameLiveView do
  use Phoenix.LiveView

  alias IslandsEngine.GameSupervisor
  alias IslandsInterface.{GameContext, Screen}
  alias IslandsInterfaceWeb.{PresenceTracker}
  alias IslandsInterfaceWeb.Pubsub.Dispatcher
  alias Phoenix.Socket.Broadcast

  def render(assigns) do
    Phoenix.View.render(IslandsInterfaceWeb.GameView, "index.html", assigns)
  end

  def mount(%{"current_user" => %{email: email}, "_csrf_token" => csrf_token}, socket) do
    state_key = build_state_key(email)

    initial_context = %{
      current_user: email,
      csrf_token: csrf_token
    }

    state =
      with [] <- :ets.lookup(:interface_state, state_key) do
        GameContext.new()
        |> Map.merge(initial_context)
        |> Map.merge(%{
          player_islands: Screen.init_player_islands(),
          board: Screen.init_board(),
          opponent_board: Screen.init_board()
        })
        |> Dispatcher.handle([:subscribe_to_lobby])
      else
        [{^state_key, state}] ->
          context =
            state
            |> GameContext.new()
            |> Map.merge(initial_context)

          events =
            case state.game_state do
              :pending ->
                [:subscribe_to_lobby, :subscribe_to_game]

              nil ->
                [:subscribe_to_lobby]

              _ ->
                IO.inspect(context)
                [:subscribe_to_game]
            end

          Dispatcher.handle(context, events)
      end
      |> GameContext.to_enum()

    {:ok, _} = :timer.send_interval(3000, self(), :count_games)

    {:ok, assign(socket, state)}
  end

  def handle_info(%Broadcast{} = event, socket) do
    context = GameContext.new(socket.assigns)
    {:noreply, assign(socket, PresenceTracker.presence_diff(event, context))}
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
    context = GameContext.new(socket.assigns)

    :ok = PresenceTracker.track_lobby(context)

    {:noreply, assign(socket, :open_games, get_open_games())}
  end

  def handle_info(:after_join_game, socket) do
    context = GameContext.new(socket.assigns)

    :ok = PresenceTracker.track_game(context)

    state_key = build_state_key(context.current_user)
    :ets.insert(:interface_state, {state_key, socket.assigns})

    {:noreply, socket}
  end

  def handle_info(:new_game, socket) do
    {:noreply, assign(socket, :open_games, get_open_games())}
  end

  def handle_info({:new_player, %{"new_player" => new_player}}, socket) do
    context = GameContext.new(socket.assigns)
    _ = Dispatcher.handle(context, [:handshake])

    socket =
      socket
      |> assign(:player2, new_player)
      |> assign(:game_state, :setting_islands)

    {:noreply, socket}
  end

  def handle_info({:handshake, %{}}, socket) do
    context = GameContext.new(socket.assigns)
    game = context.current_game

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

  defdelegate handle_event(event_binary, params, socket),
    to: IslandsInterfaceWeb.LiveEventHandler

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

defmodule IslandsInterfaceWeb.BoardLiveView do
  @dialyzer {:nowarn_function, handle_event: 3}

  use Phoenix.LiveView

  alias IslandsInterface.Screen

  import IslandsInterfaceWeb.LiveErrorHelper,
    only: [assign_error_message: 3]

  def render(assigns) do
    Phoenix.View.render(IslandsInterfaceWeb.BoardView, "index.html", assigns)
  end

  def mount(session, socket) do
    socket =
      Enum.reduce(session, socket, fn {key, value}, socket ->
        assign(socket, key, value)
      end)

    {:ok, socket}
  end

  def handle_event("choose_island", island, socket) do
    chosen_island = String.to_existing_atom(island)

    player_islands = socket.assigns.player_islands
    player_islands = Screen.choose_island(player_islands, chosen_island)

    socket =
      socket
      |> assign(:player_islands, player_islands)
      |> assign(:current_island, chosen_island)

    ok_reply(socket)
  end

  def handle_event("position_island", <<row, col>>, socket) do
    game = socket.assigns.game
    current_player = socket.assigns.current_player
    island = socket.assigns.current_island

    socket =
      with {:ok, new_board} <- Screen.position_island(game, current_player, island, row, col) do
        player_islands =
          socket.assigns.player_islands
          |> put_in([island, :state], :positioned)

        socket
        |> assign(:player_islands, player_islands)
        |> assign(:board, new_board)
      else
        {:error, reason} ->
          assign_error_message(socket.parent_pid, socket, reason)
      end
      |> assign(:current_island, nil)

    ok_reply(socket)
  end

  def handle_event("debug_position_islands", "", socket) do
    game = socket.assigns.game
    current_player = socket.assigns.current_player

    socket =
      IslandsEngine.Island.types()
      |> Enum.zip([{1, 1}, {5, 1}, {7, 3}, {3, 5}, {8, 8}])
      |> Enum.reduce(socket, fn {island, {row, col}}, socket ->
        case Screen.position_island(game, current_player, island, row, col) do
          {:ok, new_board} ->
            player_islands =
              socket.assigns.player_islands
              |> put_in([island, :state], :positioned)

            socket
            |> assign(:player_islands, player_islands)
            |> assign(:board, new_board)

          {:error, reason} ->
            assign_error_message(socket.parent_pid, socket, reason)
        end
      end)
      |> assign(:current_island, nil)

    ok_reply(socket)
  end

  def handle_event("set_islands", _, socket) do
    game = socket.assigns.game
    player = socket.assigns.current_player

    socket =
      case Screen.set_islands(game, player) do
        {:ok, new_board} ->
          broadcast_set_islands(game, player)

          player_islands = socket.assigns.player_islands

          player_islands =
            Enum.reduce(player_islands, %{}, fn {type, info}, player_islands ->
              Map.put_new(player_islands, type, put_in(info.state, :set))
            end)

          socket
          |> assign(:board, new_board)
          |> assign(:player_islands, player_islands)

        {:error, reason} ->
          assign_error_message(socket.parent_pid, socket, reason)
      end

    ok_reply(socket)
  end

  def handle_event("guess_coordinate", <<row, col>>, socket) do
    game = socket.assigns.game
    current_player = socket.assigns.current_player
    opponent_board = socket.assigns.opponent_board

    socket =
      case Screen.guess_coordinate(game, current_player, row, col) do
        {:ok, :miss} ->
          assign(socket, :opponent_board, Screen.change_tile(opponent_board, row, col, :miss))

        {:ok, :hit, :win} ->
          broadcast_guessed_coordinates(socket.parent_pid, game, row, col)

          assign(socket, :opponent_board, Screen.change_tile(opponent_board, row, col, :forest))

        {:ok, :hit, _forested} ->
          broadcast_guessed_coordinates(socket.parent_pid, game, row, col)

          assign(socket, :opponent_board, Screen.change_tile(opponent_board, row, col, :forest))

        {:error, reason} ->
          assign_error_message(socket.parent_pid, socket, reason)
      end

    ok_reply(socket)
  end

  defp ok_reply(socket) do
    update_child_assigns(socket)

    {:noreply, socket}
  end

  defp update_child_assigns(socket) do
    send(socket.parent_pid, {:update_child_assigns, socket.assigns})
  end

  defp broadcast_set_islands(game, player) do
    Phoenix.PubSub.broadcast!(
      IslandsInterface.PubSub,
      "game:" <> game,
      {:set_islands, %{"player" => player}}
    )
  end

  defp broadcast_guessed_coordinates(pid, game, row, col) do
    Phoenix.PubSub.broadcast_from!(
      IslandsInterface.PubSub,
      pid,
      "game:" <> game,
      {:guessed_coordinates, %{"row" => row, "col" => col}}
    )
  end
end

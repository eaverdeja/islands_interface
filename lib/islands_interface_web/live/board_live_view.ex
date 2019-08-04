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
      socket
      |> assign(:board, session.board)
      |> assign(:current_island, session.current_island)
      |> assign(:player, session.player)
      |> assign(:player_islands, session.player_islands)
      |> assign(:current_player, session.current_player)

    {:ok, socket}
  end

  def handle_event("position_island", <<row, col>>, socket) do
    island = socket.assigns.current_island
    player = socket.assigns.player
    current_player = socket.assigns.current_player

    socket =
      case Screen.position_island(player, current_player, island, row, col) do
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
      |> assign(:current_island, nil)

    send(socket.parent_pid, {:update_child_assigns, socket.assigns})

    {:noreply, socket}
  end

  def handle_event("guess_coordinate", <<row, col>>, socket) do
    player = socket.assigns.player
    current_player = socket.assigns.current_player

    res = Screen.guess_coordinate(player, current_player, row, col)

    IO.inspect(res)

    {:noreply, socket}
  end
end

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

    update_child_assigns(socket)

    {:noreply, socket}
  end

  def handle_event("position_island", <<row, col>>, socket) do
    game = socket.assigns.game
    current_player = socket.assigns.current_player
    island = socket.assigns.current_island

    socket =
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
      |> assign(:current_island, nil)

    update_child_assigns(socket)

    {:noreply, socket}
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

    update_child_assigns(socket)

    {:noreply, socket}
  end

  def handle_event("guess_coordinate", <<row, col>>, socket) do
    game = socket.assigns.game
    current_player = socket.assigns.current_player

    socket =
      case Screen.guess_coordinate(game, current_player, row, col) do
        {:ok, :miss} ->
          socket

        {:ok, opponent_board, :win} ->
          broadcast_guessed_coordinates(game, row, col)

          assign(socket, :opponent_board, opponent_board)

        {:ok, opponent_board, _forested} ->
          broadcast_guessed_coordinates(game, row, col)

          assign(socket, :opponent_board, opponent_board)

        {:error, reason} ->
          assign_error_message(socket.parent_pid, socket, reason)
      end

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

  defp broadcast_guessed_coordinates(game, row, col) do
    Phoenix.PubSub.broadcast!(
      IslandsInterface.PubSub,
      "game:" <> game,
      {:guessed_coordinates, %{"row" => row, "col" => col}}
    )
  end
end

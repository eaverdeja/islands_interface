defmodule IslandsInterfaceWeb.LiveEventHandler do
  import Phoenix.LiveView, only: [assign: 2]
  import IslandsInterfaceWeb.LiveErrorHelper, only: [assign_error_message: 2]

  alias IslandsInterfaceWeb.Pubsub.Dispatcher
  alias IslandsInterface.{BoardHandler, LobbyHandler, GameContext}

  def handle_event(event_binary, params, socket) do
    context = GameContext.new(socket.assigns)

    event_binary
    |> String.split(".")
    |> dispatch_event(params, context)
    |> handle_dispatch(socket)
  end

  defp dispatch_event(["lobby" | event], params, context) do
    LobbyHandler.handle_event(event, params, context)
  end

  defp dispatch_event(["board" | event], params, context) do
    BoardHandler.handle_event(event, params, context)
  end

  defp dispatch_event(unknown_event, _params, _context) do
    IO.puts("Unknown event. Refusing to dispatch: #{inspect(unknown_event)}")

    {:ok, %{}}
  end

  defp handle_dispatch({:ok, dispatch_result, events}, socket) do
    socket = assign(socket, dispatch_result)
    context = GameContext.new(socket.assigns)
    Dispatcher.handle(events, context)

    {:noreply, socket}
  end

  defp handle_dispatch({:ok, dispatch_result}, socket) do
    {:noreply, assign(socket, dispatch_result)}
  end

  defp handle_dispatch({:error, reason}, socket) do
    {:noreply, assign_error_message(socket, reason)}
  end
end

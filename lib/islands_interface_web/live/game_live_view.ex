defmodule IslandsInterfaceWeb.GameLiveView do
  use Phoenix.LiveView

  alias IslandsInterface.{Cache, GameContext, Screen}
  alias IslandsInterfaceWeb.{PresenceTracker, MessageHandler}
  alias IslandsInterfaceWeb.Pubsub.{Dispatcher}
  alias Phoenix.Socket.Broadcast

  def render(assigns) do
    Phoenix.View.render(IslandsInterfaceWeb.GameView, "index.html", assigns)
  end

  def mount(%{"current_user" => %{email: email}, "_csrf_token" => csrf_token}, socket) do
    initial_context =
      GameContext.new(%{
        current_user: email,
        csrf_token: csrf_token
      })

    state =
      with nil <- Cache.get(initial_context) do
        initial_context
        |> Map.merge(%{
          player_islands: Screen.init_player_islands(),
          board: Screen.init_board(),
          opponent_board: Screen.init_board()
        })
        |> Dispatcher.handle([:subscribe_to_lobby])
      else
        state ->
          context = state

          events =
            case state.game_state do
              :pending ->
                [:subscribe_to_lobby, :subscribe_to_game]

              nil ->
                [:subscribe_to_lobby]

              _ ->
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

  def handle_info(message, socket) do
    context = GameContext.new(socket.assigns)

    response = MessageHandler.handle(message, context)

    reply_to_info(socket, response)
  end

  defdelegate handle_event(event_binary, params, socket),
    to: IslandsInterfaceWeb.LiveEventHandler

  def terminate(reason, socket) do
    IO.inspect(reason, label: "BOOM")

    socket.assigns
    |> GameContext.new()
    |> Cache.save()
  end

  defp reply_to_info(socket, attrs) when is_map(attrs),
    do: {:noreply, assign(socket, attrs)}

  defp reply_to_info(socket, _), do: {:noreply, socket}
end

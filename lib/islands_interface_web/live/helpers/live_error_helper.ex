defmodule IslandsInterfaceWeb.LiveErrorHelper do
  import Phoenix.LiveView, only: [assign: 3]

  @error_messages %{
    already_started: "Game already started! Choose a different name...",
    no_game: "There is no game with this name!",
    overlapping_island: "Overlapping islands!",
    invalid_coordinate: "Invalid coordinates!",
    error: "Invalid move!"
  }

  @error_message_timeout 4000

  def assign_error_message(socket, reason) do
    assign_error_message(self(), socket, reason)
  end

  def assign_error_message(pid, socket, reason) do
    message = get_error_message(reason)
    {:ok, _} = :timer.send_after(@error_message_timeout, pid, :clean_error_message)

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

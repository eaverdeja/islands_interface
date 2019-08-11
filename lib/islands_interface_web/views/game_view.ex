defmodule IslandsInterfaceWeb.GameView do
  use IslandsInterfaceWeb, :view

  def get_visibility(param),
    do: if(param, do: "show", else: "hide")

  def get_game_state(state) do
    case state do
      nil -> "No game"
      :pending -> "Waiting for second player"
      :setting_islands -> "Setting islands"
      :player1_set -> "Player 1 is set"
      :player2_set -> "Player 2 is set"
      :game_on -> "Game on!"
      :game_over -> "Game over"
      _ -> "Unknown state"
    end
  end

  def selected_attr(game, game),
    do: "selected=\"selected\""

  def selected_attr(_, _), do: ""
end

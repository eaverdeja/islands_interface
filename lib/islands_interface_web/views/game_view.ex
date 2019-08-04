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
      _ -> "Unknown state"
    end
  end
end

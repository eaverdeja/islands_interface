defmodule IslandsInterface.GameContext do
  defstruct [
    :csrf_token,
    :player1,
    :player2,
    :current_island,
    :error_message,
    :current_player,
    :current_user,
    :won_game,
    :game_state,
    :game_log,
    :current_game,
    player_islands: %{},
    board: %{},
    opponent_board: %{},
    games_running: 0,
    game_already_started: false,
    open_games: []
  ]

  def new(opts \\ %{}) do
    Map.merge(%__MODULE__{}, opts)
  end

  def to_enum(%__MODULE__{} = context), do: Map.to_list(context)
end

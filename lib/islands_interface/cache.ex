defmodule IslandsInterface.Cache do
  alias IslandsInterface.GameContext

  def get(%GameContext{current_user: current_user}) do
    state_key = build_state_key(current_user)

    case :ets.lookup(:interface_state, state_key) do
      [] -> nil
      [{^state_key, state}] -> state
    end
  end

  def save(%GameContext{current_user: current_user} = context) do
    state_key = build_state_key(current_user)

    :ets.insert(:interface_state, {state_key, context})
  end

  defp build_state_key(current_user) do
    :"#{current_user}_state"
  end
end

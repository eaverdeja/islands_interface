defmodule IslandsInterfaceWeb.GameView do
  use IslandsInterfaceWeb, :view

  def get_player_islands(player_islands) do
    player_islands
    |> Map.to_list()
    |> Enum.map(fn {_type, island} -> island end)
  end

  def get_tile_class(type), do: Atom.to_string(type)

  def get_visibility(param),
    do: if(param, do: "show", else: "hide")
end

defmodule IslandsInterfaceWeb.BoardView do
  use IslandsInterfaceWeb, :view

  def get_player_islands(player_islands) do
    player_islands
    |> Map.to_list()
    |> Enum.map(fn {_type, island} -> island end)
  end

  def all_islands_positioned?(player_islands),
    do: Enum.all?(player_islands, fn {_type, island} -> island.state == :positioned end)

  def get_tile_class(type), do: Atom.to_string(type)

  def get_tile_event(current_island) do
    case current_island do
      nil -> "guess_coordinate"
      _ -> "position_island"
    end
  end
end

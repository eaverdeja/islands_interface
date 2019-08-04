defmodule IslandsInterfaceWeb.BoardView do
  use IslandsInterfaceWeb, :view

  def get_tile_class(type), do: Atom.to_string(type)

  def get_tile_event(current_island) do
    case current_island do
      nil -> "guess_coordinate"
      _ -> "position_island"
    end
  end
end

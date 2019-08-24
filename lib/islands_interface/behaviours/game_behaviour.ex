defmodule IslandsInterface.GameBehaviour do
  @callback via_tuple(String.t()) :: {:via, Registry, {atom(), String.t()}} | no_return

  @callback add_player(String.t(), String.t()) :: :ok | :error

  @callback position_island(String.t(), atom(), atom(), integer(), integer()) ::
              {:ok, map()} | {:error, atom()}

  @callback set_islands(String.t(), atom()) ::
              {:ok, map()} | {:error, atom()}

  @callback guess_coordinate(String.t(), atom(), integer(), integer()) ::
              {:ok, :miss} | {:ok, :hit, map()} | {:ok, :hit, :win} | {:error, :error}
end

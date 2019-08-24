ExUnit.start()

Ecto.Adapters.SQL.Sandbox.mode(IslandsInterface.Repo, :manual)

Mox.defmock(IslandsInterface.GameMock, for: IslandsInterface.GameBehaviour)

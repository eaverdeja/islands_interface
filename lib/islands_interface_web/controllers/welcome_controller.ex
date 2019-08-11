defmodule IslandsInterfaceWeb.WelcomeController do
  use IslandsInterfaceWeb, :controller

  import Phoenix.LiveView.Controller, only: [live_render: 3]

  def index(conn, %{}) do
    session =
      get_session(conn)
      |> Map.put_new("current_user", Pow.Plug.current_user(conn))

    live_render(conn, IslandsInterfaceWeb.GameLiveView, session: session)
  end
end

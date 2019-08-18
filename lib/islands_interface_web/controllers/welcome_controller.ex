defmodule IslandsInterfaceWeb.WelcomeController do
  use IslandsInterfaceWeb, :controller

  import Phoenix.LiveView.Controller, only: [live_render: 3]

  def index(conn, %{}) do
    session =
      conn
      |> get_session()
      |> Map.put_new("current_user", Pow.Plug.current_user(conn))
      |> Map.put("_csrf_token", Phoenix.Controller.get_csrf_token())

    live_render(conn, IslandsInterfaceWeb.GameLiveView, session: session)
  end
end

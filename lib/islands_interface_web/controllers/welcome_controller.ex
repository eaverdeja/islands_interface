defmodule IslandsInterfaceWeb.WelcomeController do
  use IslandsInterfaceWeb, :controller

  import Phoenix.LiveView.Controller, only: [live_render: 3]

  def index(conn, %{}) do
    live_render(conn, IslandsInterfaceWeb.GameLiveView, session: %{})
  end
end

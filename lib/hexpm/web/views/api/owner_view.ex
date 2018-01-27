defmodule HexpmWeb.API.OwnerView do
  use HexpmWeb, :view
  alias HexpmWeb.API.UserView

  def render("index." <> format, %{owners: owners}) do
    render(UserView, "index." <> format, users: owners, show_email: true)
  end
end

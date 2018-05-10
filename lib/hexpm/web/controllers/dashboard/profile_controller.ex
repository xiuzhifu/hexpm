defmodule Hexpm.Web.Dashboard.ProfileController do
  use Hexpm.Web, :controller

  plug :requires_login

  def index(conn, _params) do
    user = conn.assigns.current_user
    render_profile(conn, User.update_profile(user, %{}))
  end

  def update(conn, params) do
    user = conn.assigns.current_user

    case Users.update_profile(user, params["user"], audit: audit_data(conn)) do
      {:ok, _user} ->
        conn
        |> put_flash(:info, "Profile updated successfully.")
        |> redirect(to: Routes.profile_path(conn, :index))

      {:error, changeset} ->
        conn
        |> put_status(400)
        |> render_profile(changeset)
    end
  end

  defp render_profile(conn, changeset) do
    render(
      conn,
      "index.html",
      title: "Dashboard - Public profile",
      container: "container page dashboard",
      changeset: changeset
    )
  end
end

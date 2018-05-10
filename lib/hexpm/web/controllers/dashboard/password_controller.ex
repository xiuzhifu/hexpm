defmodule Hexpm.Web.Dashboard.PasswordController do
  use Hexpm.Web, :controller

  plug :requires_login

  def index(conn, _params) do
    user = conn.assigns.current_user
    render_password(conn, User.update_password(user, %{}))
  end

  def update(conn, params) do
    user = conn.assigns.current_user

    case Users.update_password(user, params["user"], audit: audit_data(conn)) do
      {:ok, _user} ->
        conn
        |> put_flash(:info, "Your password has been updated.")
        |> redirect(to: Routes.password_path(conn, :index))

      {:error, changeset} ->
        conn
        |> put_status(400)
        |> render_password(changeset)
    end
  end

  defp render_password(conn, changeset) do
    render(
      conn,
      "password.html",
      title: "Dashboard - Change password",
      container: "container page dashboard",
      changeset: changeset
    )
  end
end

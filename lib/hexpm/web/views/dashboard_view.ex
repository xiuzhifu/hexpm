defmodule Hexpm.Web.DashboardView do
  use Hexpm.Web, :view

  defp account_settings() do
    [
      profile: {"Profile", Routes.profile_path(:index)},
      password: {"Password", Routes.password_path(:index)},
      email: {"Email", Routes.email_path(:index)},
      keys: {"Keys", Routes.key_path(:index)}
    ]
  end

  defp selected_setting(conn, id) do
    if Enum.take(conn.path_info, -2) == ["dashboard", Atom.to_string(id)] do
      "selected"
    end
  end

  defp selected_repository(conn, name) do
    if Enum.take(conn.path_info, -2) == ["repos", name] do
      "selected"
    end
  end
end

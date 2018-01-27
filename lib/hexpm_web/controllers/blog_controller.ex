defmodule HexpmWeb.BlogController do
  use HexpmWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html", [
      title: "Blog",
      container: "container page blog"
    ])
  end

  def show(conn, %{"name" => name}) do
    if name in all_slugs() do
      render(conn, "#{name}.html", [
        title: title(name),
        container: "container page blog"
      ])
    else
      not_found(conn)
    end
  end

  defp all_slugs() do
    HexpmWeb.BlogView.all_templates()
    |> Enum.map(&Path.rootname/1)
  end

  defp title(slug) do
    slug
    |> String.replace("-", " ")
    |> String.capitalize()
  end
end

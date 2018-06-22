defmodule Hexpm.Web.Plugs.AttackTest do
  use ExUnit.Case, async: true
  use Plug.Test
  import Hexpm.Factory

  defmodule Hello do
    # need to use Phoenix.Controller because RateLimit.Plug uses ErrorView
    # which in turn requres `plug :accepts`
    use Phoenix.Controller

    plug :accepts, ~w(json)
    plug Hexpm.Web.Plugs.Attack

    def index(conn, _params) do
      send_resp(conn, 200, "Hello, World!")
    end
  end

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Hexpm.Repo)
    PlugAttack.Storage.Ets.clean(Hexpm.Web.Plugs.Attack)
    %{user: insert(:user)}
  end

  describe "throttle" do
    test "allows unauthenticated requests when limit is not exceeded" do
      conn = request_ip({0, 0, 0, 0})
      assert conn.status == 200
      assert get_resp_header(conn, "x-ratelimit-limit") == ["100"]
      assert get_resp_header(conn, "x-ratelimit-remaining") == ["99"]
    end

    test "allows authenticated requests when limit is not exceeded", %{user: user} do
      conn = request_user(user)
      assert conn.status == 200
      assert get_resp_header(conn, "x-ratelimit-limit") == ["500"]
      assert get_resp_header(conn, "x-ratelimit-remaining") == ["499"]
    end

    test "halts requests when ip limit is exceeded" do
      Enum.each(99..0, fn i ->
        conn = request_ip({1, 1, 1, 1})
        assert conn.status == 200
        assert get_resp_header(conn, "x-ratelimit-remaining") == ["#{i}"]
      end)

      conn = request_ip({1, 1, 1, 1})
      assert conn.status == 429

      assert conn.resp_body ==
               Jason.encode!(%{status: 429, message: "API rate limit exceeded for IP 1.1.1.1"})
    end

    test "halts requests when user limit is exceeded", %{user: user} do
      Enum.each(499..0, fn i ->
        conn = request_user(user)
        assert conn.status == 200
        assert get_resp_header(conn, "x-ratelimit-remaining") == ["#{i}"]
      end)

      conn = request_user(user)
      assert conn.status == 429

      assert conn.resp_body ==
               Jason.encode!(%{
                 status: 429,
                 message: "API rate limit exceeded for user #{user.id}"
               })
    end

    test "allows requests again when limit expired" do
      conn = request_ip({2, 2, 2, 2})
      assert get_resp_header(conn, "x-ratelimit-remaining") == ["99"]

      PlugAttack.Storage.Ets.clean(Hexpm.Web.Plugs.Attack)

      conn = request_ip({2, 2, 2, 2})
      assert get_resp_header(conn, "x-ratelimit-remaining") == ["99"]
    end

    test "doesn't limit requests from 127.0.0.1" do
      conn = request_ip({127, 0, 0, 1})
      assert conn.status == 200
      assert get_resp_header(conn, "x-ratelimit-remaining") == []
    end

    test "doesn't limit requests from CDN" do
      Hexpm.BlockAddress.reload()
      conn = request_ip({127, 0, 0, 255})
      assert conn.status == 200
      assert get_resp_header(conn, "x-ratelimit-remaining") == []
    end
  end

  describe "block addresses" do
    test "allows requests from IPs that are not blocked" do
      conn = request_ip({0, 0, 0, 0})
      assert conn.status == 200
      assert conn.resp_body == "Hello, World!"
    end

    test "halts requests from IPs that are blocked" do
      insert(:block_address, ip: "10.1.1.1")
      Hexpm.BlockAddress.reload()

      conn = request_ip({10, 1, 1, 1})
      assert conn.status == 403
      assert conn.resp_body == Jason.encode!(%{status: 403, message: "Blocked"})
    end

    test "allows requests again when the IP is unblocked" do
      blocked_address = insert(:block_address, ip: "20.2.2.2")
      Hexpm.BlockAddress.reload()

      conn = request_ip({20, 2, 2, 2})
      assert conn.status == 403
      assert conn.resp_body == Jason.encode!(%{status: 403, message: "Blocked"})

      Hexpm.Repo.delete!(blocked_address)
      Hexpm.BlockAddress.reload()

      conn = request_ip({20, 2, 2, 2})
      assert conn.status == 200
      assert conn.resp_body == "Hello, World!"
    end
  end

  defp request_ip(remote_ip) do
    conn(:get, "/")
    |> Map.put(:remote_ip, remote_ip)
    |> assign(:current_user, nil)
    |> assign(:current_organization, nil)
    |> Hello.call(:index)
  end

  defp request_user(user) do
    conn(:get, "/")
    |> Map.put(:remote_ip, {10, 0, 0, 1})
    |> assign(:current_user, user)
    |> assign(:current_organization, nil)
    |> Hello.call(:index)
  end
end

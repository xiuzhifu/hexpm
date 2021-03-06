defmodule Hexpm.Web.API.AuthControllerTest do
  use Hexpm.ConnCase, async: true

  setup do
    owned_repo = insert(:organization, public: false)
    unowned_repo = insert(:organization, public: false)
    user = insert(:user)
    insert(:organization_user, organization: owned_repo, user: user)

    full_key =
      insert(
        :key,
        user: user,
        permissions: [
          build(:key_permission, domain: "api"),
          build(:key_permission, domain: "repository", resource: owned_repo.name)
        ]
      )

    api_key = insert(:key, user: user, permissions: [build(:key_permission, domain: "api")])

    repo_key =
      insert(
        :key,
        user: user,
        permissions: [build(:key_permission, domain: "repository", resource: owned_repo.name)]
      )

    all_repos_key =
      insert(:key, user: user, permissions: [build(:key_permission, domain: "repositories")])

    unowned_repo_key =
      insert(
        :key,
        user: user,
        permissions: [build(:key_permission, domain: "repository", resource: unowned_repo.name)]
      )

    {:ok,
     [
       owned_repo: owned_repo,
       unowned_repo: unowned_repo,
       user: user,
       full_key: full_key,
       api_key: api_key,
       repo_key: repo_key,
       all_repos_key: all_repos_key,
       unowned_repo_key: unowned_repo_key
     ]}
  end

  describe "GET /api/auth" do
    test "without key" do
      build_conn()
      |> get("api/auth", domain: "api")
      |> response(401)
    end

    test "with invalid key" do
      build_conn()
      |> put_req_header("authorization", "ABC")
      |> get("api/auth", domain: "api")
      |> response(401)
    end

    test "without domain returns 400", %{full_key: key} do
      build_conn()
      |> put_req_header("authorization", key.user_secret)
      |> get("api/auth")
      |> response(400)
    end

    test "authenticate full key", %{
      full_key: key,
      owned_repo: owned_repo,
      unowned_repo: unowned_repo
    } do
      build_conn()
      |> put_req_header("authorization", key.user_secret)
      |> get("api/auth", domain: "api")
      |> response(204)

      build_conn()
      |> put_req_header("authorization", key.user_secret)
      |> get("api/auth", domain: "repository", resource: owned_repo.name)
      |> response(204)

      build_conn()
      |> put_req_header("authorization", key.user_secret)
      |> get("api/auth", domain: "repository", resource: unowned_repo.name)
      |> response(401)

      build_conn()
      |> put_req_header("authorization", key.user_secret)
      |> get("api/auth", domain: "repository", resource: "BADREPO")
      |> response(401)

      build_conn()
      |> put_req_header("authorization", key.user_secret)
      |> get("api/auth", domain: "repository")
      |> response(401)
    end

    test "authenticate api key", %{api_key: key} do
      build_conn()
      |> put_req_header("authorization", key.user_secret)
      |> get("api/auth", domain: "api")
      |> response(204)

      build_conn()
      |> put_req_header("authorization", key.user_secret)
      |> get("api/auth", domain: "api", resource: "read")
      |> response(204)

      build_conn()
      |> put_req_header("authorization", key.user_secret)
      |> get("api/auth", domain: "api", resource: "write")
      |> response(204)

      build_conn()
      |> put_req_header("authorization", key.user_secret)
      |> get("api/auth", domain: "repository", resource: "myrepo")
      |> response(401)
    end

    test "authenticate read api key", %{user: user} do
      permission = build(:key_permission, domain: "api", resource: "read")
      key = insert(:key, user: user, permissions: [permission])

      build_conn()
      |> put_req_header("authorization", key.user_secret)
      |> get("api/auth", domain: "api", resource: "read")
      |> response(204)

      build_conn()
      |> put_req_header("authorization", key.user_secret)
      |> get("api/auth", domain: "api", resource: "write")
      |> response(401)
    end

    test "authenticate write api key", %{user: user} do
      permission = build(:key_permission, domain: "api", resource: "write")
      key = insert(:key, user: user, permissions: [permission])

      build_conn()
      |> put_req_header("authorization", key.user_secret)
      |> get("api/auth", domain: "api", resource: "write")
      |> response(204)

      build_conn()
      |> put_req_header("authorization", key.user_secret)
      |> get("api/auth", domain: "api", resource: "read")
      |> response(401)
    end

    test "authenticate repo key with all repositories", %{
      all_repos_key: key,
      owned_repo: owned_repo,
      unowned_repo: unowned_repo
    } do
      build_conn()
      |> put_req_header("authorization", key.user_secret)
      |> get("api/auth", domain: "api")
      |> response(401)

      build_conn()
      |> put_req_header("authorization", key.user_secret)
      |> get("api/auth", domain: "repositories")
      |> response(204)

      build_conn()
      |> put_req_header("authorization", key.user_secret)
      |> get("api/auth", domain: "repository", resource: owned_repo.name)
      |> response(204)

      build_conn()
      |> put_req_header("authorization", key.user_secret)
      |> get("api/auth", domain: "repository", resource: unowned_repo.name)
      |> response(403)

      build_conn()
      |> put_req_header("authorization", key.user_secret)
      |> get("api/auth", domain: "repository", resource: "BADREPO")
      |> response(403)
    end

    test "authenticate repository key against repository without access permissions", %{
      unowned_repo_key: key,
      unowned_repo: unowned_repo
    } do
      build_conn()
      |> put_req_header("authorization", key.user_secret)
      |> get("api/auth", domain: "repository", resource: unowned_repo.name)
      |> response(403)
    end

    test "authenticate repository key against repository without active billing", %{user: user} do
      repo = insert(:organization, billing_active: false)
      insert(:organization_user, organization: repo, user: user)

      key =
        insert(
          :key,
          user: user,
          permissions: [build(:key_permission, domain: "repository", resource: repo.name)]
        )

      build_conn()
      |> put_req_header("authorization", key.user_secret)
      |> get("api/auth", domain: "repository", resource: repo.name)
      |> response(403)
    end
  end
end

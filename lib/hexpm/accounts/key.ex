defmodule Hexpm.Accounts.Key do
  use Hexpm.Web, :schema

  @derive Hexpm.Web.Stale
  @derive {Phoenix.Param, key: :name}

  schema "keys" do
    field :name, :string
    field :secret_first, :string
    field :secret_second, :string
    field :revoked_at, :naive_datetime
    timestamps()

    embeds_one :last_use, Use, on_replace: :delete do
      field :used_at, :naive_datetime
      field :user_agent, :string
      field :ip, :string
    end

    belongs_to :user, User
    belongs_to :organization, Organization
    embeds_many :permissions, KeyPermission

    # Only used after key creation to hold the user's key (not hashed)
    # the user key will never be retrievable after this
    field :user_secret, :string, virtual: true
  end

  def changeset(key, user_or_organization, params) do
    cast(key, params, ~w(name)a)
    |> validate_required(~w(name)a)
    |> add_keys()
    |> prepare_changes(&unique_name/1)
    |> cast_embed(:permissions, with: &KeyPermission.changeset(&1, user_or_organization, &2))
    |> put_default_embed(:permissions, [%KeyPermission{domain: "api"}])
  end

  def build(user_or_organization, params) do
    build_assoc(user_or_organization, :keys)
    |> changeset(user_or_organization, params)
  end

  def all(user_or_organization) do
    from(
      k in assoc(user_or_organization, :keys),
      where: is_nil(k.revoked_at)
    )
  end

  def get(user_or_organization, name) do
    from(
      k in assoc(user_or_organization, :keys),
      where: k.name == ^name and is_nil(k.revoked_at)
    )
  end

  def get_revoked(user_or_organization, name) do
    from(
      k in assoc(user_or_organization, :keys),
      where: k.name == ^name and not is_nil(k.revoked_at)
    )
  end

  def revoke(key, revoked_at \\ NaiveDateTime.utc_now()) do
    key
    |> change()
    |> put_change(:revoked_at, key.revoked_at || revoked_at)
    |> validate_required(:revoked_at)
  end

  def revoke_by_name(user_or_organization, key_name, revoked_at \\ NaiveDateTime.utc_now()) do
    from(
      k in assoc(user_or_organization, :keys),
      where: k.name == ^key_name and is_nil(k.revoked_at),
      update: [
        set: [
          revoked_at: fragment("?", ^revoked_at),
          updated_at: ^NaiveDateTime.utc_now()
        ]
      ]
    )
  end

  def revoke_all(user_or_organization, revoked_at \\ NaiveDateTime.utc_now()) do
    from(
      k in assoc(user_or_organization, :keys),
      where: is_nil(k.revoked_at),
      update: [
        set: [
          revoked_at: fragment("?", ^revoked_at),
          updated_at: ^NaiveDateTime.utc_now()
        ]
      ]
    )
  end

  def gen_key() do
    user_secret = Auth.gen_key()
    app_secret = Application.get_env(:hexpm, :secret)

    <<first::binary-size(32), second::binary-size(32)>> =
      :crypto.hmac(:sha256, app_secret, user_secret)
      |> Base.encode16(case: :lower)

    {user_secret, first, second}
  end

  def update_last_use(key, params) do
    key
    |> change()
    |> put_embed(:last_use, struct(Key.Use, params))
  end

  defp add_keys(changeset) do
    {user_secret, first, second} = gen_key()

    changeset
    |> put_change(:user_secret, user_secret)
    |> put_change(:secret_first, first)
    |> put_change(:secret_second, second)
  end

  defp unique_name(changeset) do
    {:ok, name} = fetch_change(changeset, :name)

    source =
      if changeset.data.organization_id do
        assoc(changeset.data, :organization)
      else
        assoc(changeset.data, :user)
      end

    names =
      from(
        s in source,
        join: k in assoc(s, :keys),
        where: is_nil(k.revoked_at),
        select: k.name
      )
      |> changeset.repo.all
      |> Enum.into(MapSet.new())

    name = if MapSet.member?(names, name), do: find_unique_name(name, names), else: name

    put_change(changeset, :name, name)
  end

  defp find_unique_name(name, names, counter \\ 2) do
    name_counter = "#{name}-#{counter}"

    if MapSet.member?(names, name_counter) do
      find_unique_name(name, names, counter + 1)
    else
      name_counter
    end
  end

  def verify_permissions?(key, "api", resource) do
    Enum.any?(key.permissions, fn permission ->
      permission.domain == "api" and
        (is_nil(permission.resource) or permission.resource == resource)
    end)
  end

  def verify_permissions?(key, "repositories", _resource) do
    Enum.any?(key.permissions, &(&1.domain == "repositories"))
  end

  def verify_permissions?(key, "repository", resource) do
    Enum.any?(key.permissions, fn permission ->
      (permission.domain == "repository" and permission.resource == resource) or
        permission.domain == "repositories"
    end)
  end

  def verify_permissions?(_key, nil, _resource) do
    false
  end
end

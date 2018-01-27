defmodule Hexpm.Repository.RepositoryUser do
  use HexpmWeb, :schema

  schema "repository_users" do
    field :role, :string

    belongs_to :repository, Repository
    belongs_to :user, User

    timestamps()
  end
end

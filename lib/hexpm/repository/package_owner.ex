defmodule Hexpm.Repository.PackageOwner do
  use HexpmWeb, :schema

  schema "package_owners" do
    belongs_to :package, Package
    belongs_to :owner, User
  end
end

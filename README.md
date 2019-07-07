# Parameters

Declarative parameter validation riding on the shoulder of a giant.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `parameters` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:parameters, "~> 2.0"}
  ]
end
```

## Usage

```elixir
defmodule MyApp.PostController do
  use MyApp, :web
  use Parameters

  params do
    # Schema fields + Changeset.validate_required
    optional :limit, :integer, default: 10
    optional :page, :integer, default: 1
    requires :query, :string

    # Schema embeds_many
    requires :profiles, :array do
      requires :access_key, :string
      requires :secret_key, :string
    end

    # Schema embeds_one
    requires :profile, :map do
      requires :access_key, :string
      requires :secret_key, :string
    end
  end

  def index(conn, _params) do
    with {:ok, params} <- params_for(conn) do
      json(conn, params)
    else
      {:error, %Ecto.Changeset{}} ->
        # do something
    end
  end
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/parameters](https://hexdocs.pm/parameters).


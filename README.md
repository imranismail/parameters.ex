# Parameters

A simple params validation package built on top of Ecto. I mostly use it to do simple typecasting on query params and simple required/optional parameter validation.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `parameters` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:parameters, "~> 0.2.0"}
  ]
end
```

## Usage

```elixir
defmodule MyApp.PostController do
  use MyApp, :web
  use Parameters

  params :index do
    optional :limit, :integer, default: 10
    optional :page, :integer, default: 1
    requires :query, :string
  end

  def index(conn, params) do
    json(conn, params)
  end
end
```

```
GET /posts?query=food
{"limit": 10, "page": 1, query: "food"}

GET /posts?limit=haha&page=hoho
=> %Parameters.InvalidError{plug_status: 400, changeset: changeset}
Invalid parameters
  %{
    limit: ["must be a number"],
    page: ["must be a number"],
    query: ["must be present"]
  }
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/parameters](https://hexdocs.pm/parameters).


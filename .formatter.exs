locals_without_parens = [
  params: 1,
  requires: 2,
  requires: 3,
  optional: 2,
  optional: 3
]

[
  import_deps: [:ecto],
  inputs: ["*.{ex,exs}", "{config,lib,test}/**/*.{ex,exs}"],
  locals_without_parens: locals_without_parens,
  export: [
    locals_without_parens: locals_without_parens
  ]
]

# lethe

A marginally-better (WIP) query DSL for Mnesia. Originally implemented for
[신경](https://singyeong.org).

Matchspecs suck, so this is a sorta-better alternative.

**WARNING:** Currently, only read operations are supported. This may or may not
change in the future.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `lethe` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:lethe, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/lethe](https://hexdocs.pm/lethe).


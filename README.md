# lethe

A marginally-better (WIP) query DSL for Mnesia. Originally implemented for
[신경](https://singyeong.org).

Matchspecs suck, so this is a sorta-better alternative.

**WARNING:** Currently, only read operations are supported. This may or may not
change in the future.

## Roadmap

- [x] Select all fields of a record
- [x] Select some fields of a record
- [x] Limit number of records returned
- [ ] Query operators
  - [ ] `+`, `-`, `*`, `div`, `rem`, `>`, `>=`, `<`, `<=`, `!=`
  - [ ] Bitwise operators
  - [ ] Tuple, list, and map operators (`map_size`, `hd`, `tl`, `element`, etc.)
  - [ ] Misc. math functions (`abs`, `trunc`, etc.)
  - [ ] Boolean operators
    - [ ] Logical AND/OR/etc.
    - [ ] `is_pid`/`is_binary`/etc.

## Installation

[Get it on Hex.](https://hex.pm/packages/lethe)

[Read the docs.](https://hexdocs.pm/lethe)

## Usage

```Elixir
# Create a table...
table = :table
:mnesia.create_schema []
:mnesia.start()
:mnesia.create_table table, [attributes: [:integer, :string, :map]]

# ...and add some indexes...
:mnesia.add_table_index table, :integer
:mnesia.add_table_index table, :string
:mnesia.add_table_index table, :map

# ...and some test data.
n = fn -> :rand.uniform 1_000_000_000_000_000_000_000_000_000_000_000_000_000_000_000 end
for i <- 1..10_000, do: :mnesia.dirty_write {table, i, "#{n.()}", %{n.() => "#{n.()}"}}

# Now let's run some queries!
# Lethe's query DSL allows you to use the names of your table attributes,
# rather than forcing you to think about what their index in the record is, or
# anything else like that.
# Currently, Lethe requires that you compile your queries before running them.
# This is primarily done to aid in debugging, and a `Lethe.compile_and_run/1`
# is likely to happen in the future.

# Select one record and all its fields
{:ok, [{integer, string, map}]} =
  table
  |> Lethe.new
  |> Lethe.limit(1)
  |> Lethe.select_all
  |> Lethe.compile
  |> Lethe.run

# Select a single field from a single record
{:ok, [integer]} =
  table
  |> Lethe.new
  |> Lethe.limit(1)
  |> Lethe.select(:integer)
  |> Lethe.compile
  |> Lethe.run

# Select a bunch of records at once
{:ok, records} =
  table
  |> Lethe.new
  |> Lethe.limit(100)
  |> Lethe.select_all
  |> Lethe.compile
  |> Lethe.run

# Select specific fields from a record
{:ok, [{int, map}, {int, map}]} =
  table
  |> Lethe.new
  |> Lethe.limit(2)
  |> Lethe.select([:integer, :map])
  |> Lethe.compile
  |> Lethe.run
```
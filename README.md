# Lethe

> Lethe
> /ˈli θi/ • *noun* <sup><sup>(try it with [IPA Reader](http://ipa-reader.xyz))</sup></sup>
> 1. *Classical Mythology.* A river in Hades whose water caused forgetfulness of the past in those who drank of it.

A marginally-better (WIP) query DSL for Mnesia. Originally implemented for
[신경](https://singyeong.org).

Matchspecs suck, so this is a sorta-better alternative.

**WARNING:** Currently, only read operations are supported. This may or may not
change in the future.

### Things that may trip you up

- The map functions `is_map_key` and `map_get` take arguments in the order
  `(key, map)`, NOT `(map, key)`!

## Roadmap

- [x] Select all fields of a record
- [x] Select some fields of a record
- [x] Limit number of records returned
- [x] Query operators
  - [x] `+`, `-`, `*`, `div`, `rem`, `>`, `>=`, `<`, `<=`, `!=`
  - [x] Bitwise operators
  - [x] Tuple, list, and map operators (`map_size`, `hd`, `tl`, `element`, etc.)
  - [x] Misc. math functions (`abs`, `trunc`, etc.)
  - [x] Boolean operators
    - [x] Logical AND/OR/etc.
    - [x] `is_pid`/`is_binary`/etc.
- [ ] Write DSL

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
for i <- 1..10_000, do: :mnesia.dirty_write {table, i, "#{n.()}", %{i => "#{n.()}"}}

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

# Select all fields from all records
# `Lethe.select_all` and `Lethe.limit(:all)` are the default settings.
{:ok, all_records} =
  table
  |> Lethe.new
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

# Now let's use some operators!
# Lethe internally rewrites all of these expressions into Mnesia guard form.

# Select all values where :integer * 2 <= 10
{:ok, res} =
  table
  |> Lethe.new
  |> Lethe.select(:integer)
  |> Lethe.where(:integer * 2 <= 10)
  |> Lethe.compile
  |> Lethe.run

# Select all values where :integer * 2 >= 4 and :integer * 2 <= 10
{:ok, res} =
  table
  |> Lethe.new
  |> Lethe.select(:integer)
  |> Lethe.where(:integer * 2 >= 4 and :integer * 2 <= 10)
  |> Lethe.compile
  |> Lethe.run

# An example of a very complicated query
{:ok, res} =
  table
  |> Lethe.new
  |> Lethe.select(:integer)
  |> Lethe.where(
    :integer * 2 == 666
      and is_map(:map)
      and is_map_key(:integer, :map)
      and map_get(:integer, :map) == :string
  )
  |> Lethe.compile
  |> Lethe.run

# Using external variables in queries
i = 333

{:ok, res} =
  table
  |> Lethe.new
  |> Lethe.select(:integer)
  |> Lethe.where(:integer * 2 == ^i * 2)
  |> Lethe.compile
  |> Lethe.run

# Using atom literals in queries
{:ok, res} =
  table
  |> Lethe.new
  |> Lethe.select(:atom)
  |> Lethe.where(:atom == &:atom)
  |> Lethe.compile
  |> Lethe.run

# See the documentation on `Lethe.where/2` for a list of all available ops
```
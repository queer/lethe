defmodule LetheTest do
  use ExUnit.Case
  doctest Lethe

  @table :table

  setup_all do
    :mnesia.create_schema []
    :mnesia.start()
    :mnesia.create_table @table, [attributes: [:integer, :string, :map]]
    :mnesia.add_table_index @table, :integer
    :mnesia.add_table_index @table, :string
    :mnesia.add_table_index @table, :map

    for i <- 1..10_000 do
      :mnesia.dirty_write {@table, i, "#{n()}", %{n() => "#{n()}"}}
    end

    on_exit fn ->
      :mnesia.delete_table @table
      :mnesia.delete_schema []
      :mnesia.stop()
    end
  end

  defp n, do: :rand.uniform 1_000_000_000_000_000_000_000_000_000_000_000_000_000_000_000

  test "run without ops works" do
    {:ok, [res]} =
      @table
      |> Lethe.new
      |> Lethe.select_all
      |> Lethe.limit(1)
      |> Lethe.compile
      |> Lethe.run

    {integer, string, map} = res
    assert is_integer(integer)
    assert integer >= 0
    assert String.valid?(string)
    assert is_map(map)
    assert 1 == map_size(map)
  end

  describe "select/2" do
    test "it selects single fields" do
      base =
        @table
        |> Lethe.new
        |> Lethe.limit(1)

      {:ok, [int]} =
        base
        |> Lethe.select(:integer)
        |> Lethe.compile
        |> Lethe.run

      assert is_integer(int)
      assert int >= 0

      {:ok, [string]} =
        base
        |> Lethe.select(:string)
        |> Lethe.compile
        |> Lethe.run

      assert is_binary(string)
      assert String.valid?(string)

      {:ok, [map]} =
        base
        |> Lethe.select(:map)
        |> Lethe.compile
        |> Lethe.run

      assert is_map(map)
      assert 1 == map_size(map)
    end

    test "it selects adjacent fields" do
      {:ok, [{int, string}]} =
        @table
        |> Lethe.new
        |> Lethe.select([:integer, :string])
        |> Lethe.limit(1)
        |> Lethe.compile
        |> Lethe.run

      assert is_integer(int)
      assert int >= 0
      assert is_binary(string)
      assert String.valid?(string)
    end

    test "it selects non-adjacent fields" do
      {:ok, [{int, map}]} =
        @table
        |> Lethe.new
        |> Lethe.select([:integer, :map])
        |> Lethe.limit(1)
        |> Lethe.compile
        |> Lethe.run

      assert is_integer(int)
      assert int >= 0
      assert is_map(map)
      assert 1 == map_size(map)
    end

    test "it selects many records" do
      {:ok, results} =
        @table
        |> Lethe.new
        |> Lethe.select_all
        |> Lethe.limit(100)
        |> Lethe.compile
        |> Lethe.run

      assert 100 = length(results)
    end
  end
end

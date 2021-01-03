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
      :mnesia.dirty_write {@table, i, "#{n()}", %{i => "#{n()}"}}
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

    test "it selects everything correctly" do
      {:ok, results} =
        @table
        |> Lethe.new
        |> Lethe.select_all
        |> Lethe.compile
        |> Lethe.run

      assert 10_000 == length(results)
    end
  end

  describe "where/2" do
    test "it handles is-functions correctly" do
      {:ok, [integer]} =
        @table
        |> Lethe.new
        |> Lethe.select(:integer)
        |> Lethe.limit(1)
        |> Lethe.where(is_integer(:integer))
        |> Lethe.compile
        |> Lethe.run

      assert is_integer(integer)
      assert integer >= 0
    end

    test "it handles logical functions correctly" do
      {:ok, [integer]} =
        @table
        |> Lethe.new
        |> Lethe.select(:integer)
        |> Lethe.limit(1)
        |> Lethe.where(is_integer(:integer) and is_binary(:string))
        |> Lethe.compile
        |> Lethe.run

      assert is_integer(integer)
      assert integer >= 0
    end

    test "it handles comparison functions correctly" do
      {:ok, [{integer, string}]} =
        @table
        |> Lethe.new
        |> Lethe.select([:integer, :string])
        |> Lethe.where(:integer == 5)
        |> Lethe.compile
        |> Lethe.run

      assert 5 == integer
      assert is_binary(string)
      assert String.valid?(string)
    end

    test "work when many operators used" do
      {:ok, res} =
        @table
        |> Lethe.new
        |> Lethe.select(:integer)
        |> Lethe.limit(:all)
        |> Lethe.where(:integer * 2 <= 10)
        |> Lethe.compile
        |> Lethe.run

      # We can't guarantee term ordering, so it's necessary to sort the output
      # first.
      assert [1, 2, 3, 4, 5] == Enum.sort(res)
    end

    test "it handles map_size properly" do
      {:ok, [map]} =
        @table
        |> Lethe.new
        |> Lethe.select(:map)
        |> Lethe.limit(1)
        |> Lethe.where(map_size(:map) == 1)
        |> Lethe.compile
        |> Lethe.run

      assert 1 == map_size(map)
    end

    test "it handles is_map_key properly" do
      {:ok, [{integer, map}]} =
        @table
        |> Lethe.new
        |> Lethe.select([:integer, :map])
        |> Lethe.limit(1)
        |> Lethe.where(:integer == 1)
        |> Lethe.where(is_map_key(1, :map))
        |> Lethe.compile
        |> Lethe.run

      assert 1 == integer
      assert 1 == map_size(map)
      assert Map.has_key?(map, 1)
    end
  end
end

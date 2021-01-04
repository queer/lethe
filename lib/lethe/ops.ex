defmodule Lethe.Ops do
  @moduledoc """
  Auto-generated Mnesia guard helpers. YOU DO NOT WANT TO USE THIS MODULE EVER.
  """

  import Kernel, except: [
    is_atom: 1,
    is_float: 1,
    is_integer: 1,
    is_list: 1,
    is_number: 1,
    is_pid: 1,
    is_port: 1,
    is_reference: 1,
    is_tuple: 1,
    is_map: 1,
    is_map_key: 2,
    is_binary: 1,
    is_function: 1,
  ]

  @is_funcs [
    :is_atom,
    :is_float,
    :is_integer,
    :is_list,
    :is_number,
    :is_pid,
    :is_port,
    :is_reference,
    :is_tuple,
    :is_map,
    :is_binary,
    :is_function,
    # TODO: This can't actually be defined as a function, how to fix?
    # :is_record,
  ]

  @logical_funcs [
    :andalso,
    :orelse,
    :not,
    :xor,
  ]

  @transform_funcs [
    :abs,
    :element,
    :hd,
    :length,
    :map_get,
    :map_size,
    :round,
    :size,
    :bit_size,
    :tl,
    :trunc,
  ]

  @operator_funcs [
    :+,
    :-,
    :*,
    :div,
    :rem,
    :band,
    :bor,
    :bxor,
    :bnot,
    :bsl,
    :bsr,
    :>,
    :>=,
    :<,
    :"=<",
    :"=:=",
    :==,
    :"=/=",
    :"/=",
    :is_map_key,
  ]

  @constant_funcs [
    :node,
    :self,
  ]

  # TODO: Optimise to not constantly make new mapsets
  def is_funcs, do: MapSet.new @is_funcs
  def logical_funcs, do: MapSet.new @logical_funcs
  def transform_funcs, do: MapSet.new @transform_funcs
  def operator_funcs, do: MapSet.new @operator_funcs
  def constant_funcs, do: MapSet.new @constant_funcs

  for f <- @is_funcs do
    # @spec unquote(f)(Lethe.field()) :: Lethe.matchspec_guard()
    def unquote(f)(key) do
      {unquote(f), key}
    end
  end

  for f <- @logical_funcs do
    # @spec unquote(f)(Lethe.matchspec_guard(), Lethe.matchspec_guard()) :: Lethe.matchspec_guard
    def unquote(f)(left, right) do
      {unquote(f), left, right}
    end
  end

  for f <- @transform_funcs do
    # @spec unquote(f)(Lethe.field() | Lethe.matchspec_guard) :: Lethe.matchspec_guard()
    def unquote(f)(value) do
      {unquote(f), value}
    end
  end

  for f <- @operator_funcs do
    # @spec unquote(f)(Lethe.field() | Lethe.matchspec_guard(), Lethe.field | Lethe.matchspec_guard()) :: Lethe.matchspec_guard
    def unquote(f)(left, right) do
      {unquote(f), left, right}
    end
  end

  for f <- @constant_funcs do
    # @spec unquote(f)() :: Lethe.matchspec_guard()
    def unquote(f)() do
      {unquote(f)}
    end
  end
end

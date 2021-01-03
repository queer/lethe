defmodule Lethe do
  @moduledoc """
  ## Lethe

  Lethe is a user-friendly query DSL for Mnesia. Currently, Lethe is focused on
  providing a sane API for reads, but I might add support for writes later.
  """

  use TypedStruct
  alias Lethe.Utils

  ######################################
  ## Basic types for the query struct ##
  ######################################

  @typedoc """
  The name of the Mnesia table to query against
  """
  @type table() :: atom()

  @typedoc """
  The fields being returned by the query. These are the names of the fields,
  not Mnesia's numeric selectors or anything of the like.
  """
  @type field() :: atom()

  @typedoc """
  The limit of values to return. If the limit is `0`, it is converted to `:all`
  internally.
  """
  @type limit() :: :all | non_neg_integer()

  @typedoc """
  The type of table lock to use.
  """
  @type lock() :: :read | :write

  ## Mnesia transaction helpers ##

  @typedoc """
  A successful transaction result.
  """
  @type transaction_success(res) :: {:ok, res}

  @typedoc """
  A failed transaction result. The inner term is the error returned by Mnesia.
  """
  @type transaction_failure() :: {:error, {:transaction_aborted, term()}}

  @typedoc """
  A result of an Mnesia transaction.
  """
  @type transaction(res) :: transaction_success(res) | transaction_failure()

  #########################
  ## Matchspec functions ##
  #########################

  @typedoc """
  A boolean function that can be invoked in a matchspec. These functions are
  used for operating on the values being queried over, such as:
  - "is X a pid?"
  - "is Y a key in X?"
  """
  @type matchspec_bool_func() ::
    :is_atom
    | :is_float
    | :is_integer
    | :is_list
    | :is_number
    | :is_pid
    | :is_port
    | :is_reference
    | :is_tuple
    | :is_map
    | :map_is_key
    | :is_binary
    | :is_function
    | :is_record
    | :and
    | :or
    | :not
    | :xor
    | :andalso
    | :orelse

  @type matchspec_guard_func() ::
    matchspec_bool_func()
    | :abs
    | :element
    | :hd
    | :length
    | :map_get
    | :map_size
    | :node
    | :round
    | :size
    | :bit_size
    | :tl
    | :trunc
    | :+
    | :-
    | :*
    | :div
    | :rem
    | :band
    | :bor
    | :bxor
    | :bnot
    | :bsl
    | :bsr
    | :>
    | :>=
    | :<
    | :"=<"
    | :"=:="
    | :==
    | :"=/="
    | :"/="
    | :self

  #####################
  ## Matchspec types ##
  #####################

  @type result() :: atom()
  @type results() :: [result()]
  @type matchspec_any() :: :_
  @type matchspec_all() :: :"$$"
  @type matchspec_variable() ::
    result()
    | matchspec_any()
    | matchspec_all()

  @type matchspec_guard() ::
    {matchspec_guard_func()}
    | {matchspec_guard_func(), matchspec_variable()}
    | {matchspec_guard_func(), matchspec_condition(), matchspec_condition()}
    | {matchspec_guard_func(), matchspec_condition(), term()}

  @type matchspec_condition() :: matchspec_variable() | matchspec_guard()

  @typedoc """
  The first `tuple()` is a `{table(), result() | matchspec_any(), ...}`
  """
  @type matchspec_element() :: {tuple(), [matchspec_condition()], results()}
  @type matchspec() :: [matchspec_element()]
  @type compiled_query() :: {table(), matchspec(), limit(), lock()}

  ###############
  ## Constants ##
  ###############

  @mnesia_specified_vars :"$$"

  @boolean_functions [
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
    :map_is_key,
    :is_binary,
    :is_function,
    :is_record,
    :and,
    :or,
    :not,
    :xor,
    :andalso,
    :orelse,
  ]

  @guard_functions MapSet.new @boolean_functions ++ [
    :abs,
    :element,
    :hd,
    :length,
    :map_get,
    :map_size,
    :node,
    :round,
    :size,
    :bit_size,
    :tl,
    :trunc,
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
    :self,
  ]

  #############
  ## Structs ##
  #############

  typedstruct module: Query do
    field :table, Lethe.table()
    field :ops, [Lethe.matchspec_condition()]
    field :fields, %{required(Lethe.field()) => non_neg_integer()}
    field :select, [Lethe.field()]
    field :lock, Lethe.lock()
    field :limit, Lethe.limit()
  end

  #####################
  ## Basic functions ##
  #####################

  @spec new(table()) :: __MODULE__.Query.t()
  def new(table) do
    keys = :mnesia.table_info table, :attributes
    key_map =
      keys
      |> Enum.with_index
      |> Enum.map(fn {k, i} -> {k, i + 1} end)
      |> Enum.into(%{})

    %__MODULE__.Query{
      table: table,
      ops: [],
      fields: key_map,
      # Select all fields by default
      select: [@mnesia_specified_vars],
      lock: :read,
      limit: :all,
    }
  end

  @spec select_all(__MODULE__.Query.t()) :: __MODULE__.Query.t()
  def select_all(%__MODULE__.Query{} = query) do
    %{query | select: [@mnesia_specified_vars]}
  end

  @spec select(__MODULE__.Query.t(), field() | [field()]) :: __MODULE__.Query.t()
  def select(%__MODULE__.Query{} = query, field) when is_atom(field), do: select(query, [field])

  def select(%__MODULE__.Query{} = query, [_ | _] = fields) do
    %{query | select: fields}
  end

  # TODO: Document that limit=0 == limit=:all
  @spec limit(__MODULE__.Query.t(), limit()) :: __MODULE__.Query.t()
  def limit(%__MODULE__.Query{} = query, :all) do
    %{query | limit: :all}
  end

  def limit(%__MODULE__.Query{} = query, limit) when limit >= 0 do
    %{query | limit: limit}
  end

  @spec compile(__MODULE__.Query.t()) :: compiled_query()
  def compile(%__MODULE__.Query{
    table: table,
    ops: ops,
    fields: fields,
    select: select,
    lock: lock,
    limit: limit,
  } = query) do
    # The spec is a list of matches. A match is defined as:
    #   source = {@table, :$1, :$2, ...}
    #   ops = [{:>, $1, 3}]
    #   select = [:$1, :$2, ...] | [:$$]
    #   {source, ops, select}
    # where:
    # - ops are `MatchCondition`s: https://erlang.org/doc/apps/erts/match_spec.html#grammar
    # - :$_ is a select-all
    # - :$$ is a select-all-in-match-head

    # Sometimes, we have fields being used in guards but not explicitly named
    # as part of the select, due to, say, not wanting them returned but still
    # wanting them to be queried on. We deal with this by recursively scanning
    # through all the guard tuples for any variable binds, then comparing them
    # to the ones we're selecting on. If a variable is selected OR bound by a
    # guard, then it's added to the match head so we can match on it properly.
    # This respects the fields the user wants returned (from `select/2`) while
    # still working correctly.
    guard_binds = search_for_bound_variables ops

    fields_as_vars =
      fields
      |> Enum.sort_by(&elem(&1, 1))
      |> Enum.map(fn {field, index} ->
        all? = select == [@mnesia_specified_vars]
        selected? = field in select
        guard_bind? = MapSet.member? guard_binds, :"$#{index}"

        cond do
          not all? and (selected? or guard_bind?) ->
            :"$#{index}"

          not all? and not selected? and not guard_bind? ->
            :_

          all? ->
            :"$#{index}"
        end
      end)

    select_as_vars =
      case select do
        [:"$$"] ->
          select

        [_ | _] when length(select) != map_size(fields) ->
          [Enum.map(select, &Utils.field_to_var(query, &1))]

        _ ->
          select
      end

    source = List.to_tuple [table | fields_as_vars]
    matchspec = [{source, ops, select_as_vars}]
    case limit do
      limit when limit in [0, :all] ->
        {table, matchspec, :all, lock}

      _ ->
        {table, matchspec, limit, lock}
    end
  end

  @spec run(compiled_query()) :: transaction(term())
  def run({table, matchspec, :all, lock}) do
    :mnesia.transaction(fn ->
      :mnesia.select table, matchspec, lock
    end)
    |> return_select_result_or_error
  end

  def run({table, matchspec, limit, lock}) do
    :mnesia.transaction(fn ->
      :mnesia.select table, matchspec, limit, lock
    end)
    |> return_select_result_or_error
  end

  #############
  ## Helpers ##
  #############

  defp return_select_result_or_error(mnesia_result) do
    case mnesia_result do
      {:atomic, [{match, _}]} ->
        {:ok, match}

      {:atomic, {match, _}} when is_list(match) ->
        # If we have this ridiculous select return result, it's suddenly really
        # not simple.
        # The data that gets returned looks like:
        #
        #   {
        #     :atomic,
        #     {
        #       [
        #         [data, ...],
        #         ...
        #       ],
        #       {
        #         op,
        #         table,
        #         {?, pid},
        #         node,
        #         storage backend,
        #         {ref, ?, ?, ref, ?, ?},
        #         ?,
        #         ?,
        #         ?,
        #         query
        #       }
        #     }
        #   }
        #
        # and we just care about the matches in the first element of the tuple
        # that comes after the :atomic.

        out =
          match
          |> Enum.map(fn
            [value] -> value
            [key | values] when is_list(values) and values != [] -> [key | values] |> List.flatten |> List.to_tuple
            value -> value
          end)

        {:ok, out}

      {:atomic, [_ | _] = match} ->
        out =
          match
          |> Enum.map(fn
            [x | []] -> x
            x when is_list(x) -> List.to_tuple x
            x -> x
          end)

        {:ok, out}

      {:atomic, []} ->
        {:ok, []}

      {:atomic, :"$end_of_table"} ->
        {:ok, []}

      {:aborted, reason} ->
        {:error, {:transaction_aborted, reason}}
    end
  end

  defp search_for_bound_variables(guards) when is_list(guards) do
    # Given a list of guards, recursively search for any and all bound
    # variables. This makes it easier to preserve a clean syntax, not need to
    # use macros, and still be able to ensure everything is properly bound.
    guards
    |> Enum.map(&search_guard/1)
    |> Enum.reduce(MapSet.new(), fn set, acc ->
      MapSet.union acc, set
    end)
  end

  defp search_guard(tuple) do
    tuple
    |> Tuple.to_list
    |> Enum.reduce(MapSet.new(), fn elem, vars ->
      cond do
        is_atom(elem) ->
          elem
          |> Atom.to_string
          |> String.match?(~r/\$\d+/)
          |> if do
            MapSet.put vars, elem
          else
            vars
          end

        is_tuple(elem) ->
          MapSet.union vars, search_guard(elem)

        true ->
          vars
      end
    end)
  end

  defmodule Utils do
    @moduledoc """
    Functions that need to be public to function across modules.

    NOT INTENDED FOR EXTERNAL CONSUMPTION.
    """
    def field_to_var(%Lethe.Query{fields: fields}, field) do
      if Map.has_key?(fields, field) do
        field_num = Map.get fields, field
        :"$#{field_num}"
      else
        raise ArgumentError, "field '#{field}' not found in: #{inspect fields}"
      end
    end
  end

  ###############
  ## Operators ##
  ###############

  @spec where(__MODULE__.Query.t(), matchspec_guard_func(), field()) :: __MODULE__.Query.t()
  def where(%__MODULE__.Query{ops: ops} = query, op, key) do
    if MapSet.member?(@guard_functions, op) do
      # Run the op function
      out = apply Lethe.Ops, op, [query, key]
      %{query | ops: ops ++ [out]}
    else
      raise ArgumentError, "lethe: unknown op: #{inspect op}"
    end
  end

  @spec where(__MODULE__.Query.t(), matchspec_guard()) :: __MODULE__.Query.t()
  def where(%__MODULE__.Query{ops: ops} = query, matchspec) do
    %{query | ops: ops ++ [matchspec]}
  end

  defmodule Ops do
    alias Lethe.Utils

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
      :map_is_key,
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
    ]

    @constant_funcs [
      :node,
      :self,
    ]

    for f <- @is_funcs do
      @spec unquote(f)(Lethe.Query.t(), Lethe.field()) :: Lethe.matchspec_guard()
      def unquote(f)(%Lethe.Query{} = query, key) when is_atom(key) do
        {unquote(f), Utils.field_to_var(query, key)}
      end
    end

    for f <- @logical_funcs do
      @spec unquote(f)(Lethe.matchspec_guard(), Lethe.matchspec_guard()) :: Lethe.matchspec_guard
      def unquote(f)(left, right) do
        {unquote(f), left, right}
      end
    end

    for f <- @transform_funcs do
      @spec unquote(f)(Lethe.Query.t(), Lethe.field() | Lethe.matchspec_guard) :: Lethe.matchspec_guard()
      def unquote(f)(%Lethe.Query{} = query, field_or_guard) do
        {unquote(f), coerce(query, field_or_guard)}
      end
    end

    for f <- @operator_funcs do
      @spec unquote(f)(Lethe.Query.t(), Lethe.field() | Lethe.matchspec_guard(), Lethe.field | Lethe.matchspec_guard()) :: Lethe.matchspec_guard
      def unquote(f)(%Lethe.Query{} = query, left, right) do
        {unquote(f), coerce(query, left), coerce(query, right)}
      end
    end

    for f <- @constant_funcs do
      @spec unquote(f)() :: Lethe.matchspec_guard()
      def unquote(f)() do
        {unquote(f)}
      end
    end

    defp coerce(query, field_or_guard) do
      cond do
        is_atom(field_or_guard) ->
          Utils.field_to_var query, field_or_guard

        is_tuple(field_or_guard) ->
          field_or_guard

        true ->
          field_or_guard
      end
    end
  end
end

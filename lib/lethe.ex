defmodule Lethe do
  @moduledoc """
  ## Lethe

  Lethe is a user-friendly query DSL for Mnesia. Currently, Lethe is focused on
  providing a sane API for reads, but I might add support for writes later.

  The default options are:

  - Select all fields (`Lethe.select_all`)
  - Read lock (`:read`)
  - Select all values (`Lethe.limit(:all)`)

  ### Querying

  Querying is started with `Lethe.new/1`. This function takes a table name as
  its sole argument, and returns a new `Lethe.Query`. Querying is controlled
  with:

  - The fields that can be returned (`Lethe.select/2` / `Lethe.select_all/1`)
  - The number of records to return (`Lethe.limit/2`)
  - The specifics of how records are selected. (`Lethe.where/2`)
  """

  use TypedStruct
  alias Lethe.Ops

  #############################################
  ## Basic types for the query functionality ##
  #############################################

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

  @typedoc """
  An Elixir expression. Used for `where` clauses.
  """
  @type expression() :: term()

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

  @type field_or_guard() :: field() | matchspec_guard()

  ###############
  ## Constants ##
  ###############

  @mnesia_specified_vars :"$$"

  ##########################
  ## Using macro for help ##
  ##########################

  #############
  ## Structs ##
  #############

  typedstruct module: Query do
    @moduledoc """
    A Lethe query. Queries are what Lethe transforms into Mnesia-compatible
    matchspecs for processing. A query is constructed from nothing but a table
    name, provided to `Lethe.new/1`. Queries have sane defaults:

    - Return all fields
    - Read lock
    - Return all matches

    Queries can be updated with several functions:

    - `Lethe.where/2`: Add a constraint to the query, like a `WHERE` clause in
      SQL.
    - `Lethe.limit/2`: Limit the number of results returned by the query.
    - `Lethe.select/2`: Choose the specific fields returned by the query.
    - `Lethe.select_all/1`: Choose to return all fields.

    When you're finished creating a query, you must then compile it with
    `Lethe.compile/1`, which converts the query into a form that can be passed
    to Mnesia. Copmiled queries can be executed with `Lethe.run/1`; while it is
    possible to take the output from `Lethe.compile/1` and run it manually,
    doing so is not advised.
    """

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

  @doc """
  Create a new query on the specified table. The names of the table attributes
  will be automatically loaded.
  """
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

  @doc """
  Select all fields from the table. This is essentially Mnesia's `:"$$"`
  selector.
  """
  @spec select_all(__MODULE__.Query.t()) :: __MODULE__.Query.t()
  def select_all(%__MODULE__.Query{} = query) do
    %{query | select: [@mnesia_specified_vars]}
  end

  @doc """
  List specific fields to be selected from the table. Either a single atom or a
  list of atoms may be provided.
  """
  @spec select(__MODULE__.Query.t(), field() | [field()]) :: __MODULE__.Query.t()
  def select(%__MODULE__.Query{} = query, field) when is_atom(field), do: select(query, [field])

  def select(%__MODULE__.Query{} = query, [_ | _] = fields) do
    %{query | select: fields}
  end

  @doc """
  Limit the number of results returned. The number is a non-negative integer,
  or the special atom `:all` to indicate all results being returned. Providing
  a limit of `0` is functionally equivalent to providing a limit of `:all`.
  """
  @spec limit(__MODULE__.Query.t(), limit()) :: __MODULE__.Query.t()
  def limit(%__MODULE__.Query{} = query, :all) do
    %{query | limit: :all}
  end

  def limit(%__MODULE__.Query{} = query, limit) when limit >= 0 do
    %{query | limit: limit}
  end

  @doc """
  Compiles the query into a tuple containing all the information needed to run
  it against an Mnesia database.
  """
  @spec compile(__MODULE__.Query.t()) :: compiled_query()
  def compile(%__MODULE__.Query{
    table: table,
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
    {guard_binds, bound_guard_funcs} = search_for_unbound_variables query

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

        [_ | _] when Kernel.length(select) != map_size(fields) ->
          [Enum.map(select, &field_to_var(query, &1))]

        _ ->
          select
      end

    source = List.to_tuple [table | fields_as_vars]
    matchspec = [{source, bound_guard_funcs, select_as_vars}]
    case limit do
      limit when limit in [0, :all] ->
        {table, matchspec, :all, lock}

      _ ->
        {table, matchspec, limit, lock}
    end
  end

  @doc """
  Runs the query against Mnesia, ensuring that results are properly limited.
  """
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

  defp search_for_unbound_variables(%__MODULE__.Query{ops: guards} = query) when is_list(guards) do
    # Given a list of guards, recursively search for any and all bound
    # variables. This makes it easier to preserve a clean syntax, not need to
    # use macros, and still be able to ensure everything is properly bound.
    guards
    |> Enum.map(&search_guard(query, &1))
    |> Enum.reduce({MapSet.new(), []}, fn {set, bound}, {acc, guards_out} ->
      acc_out = MapSet.union acc, set
      {acc_out, guards_out ++ [bound]}
    end)
  end

  defp search_guard(%__MODULE__.Query{} = query, tuple) do
    {vars, out} =
      tuple
      |> Tuple.to_list
      |> Enum.reduce({MapSet.new(), []}, fn elem, {vars, out} ->
        cond do
          is_atom(elem) ->
            elem
            |> Atom.to_string
            |> String.starts_with?("__lethe_literal")
            |> if do
              literal =
                elem
                |> Atom.to_string
                |> String.replace("__lethe_literal_", "")
                |> String.to_atom

              {vars, out ++ [literal]}
            else
              try do
                bind = field_to_var query, elem
                {MapSet.put(vars, bind), out ++ [bind]}
              rescue
                _ ->
                  {vars, out ++ [elem]}
              end
            end


          is_tuple(elem) ->
            {inner_vars, inner_out} = search_guard query, elem
            {MapSet.union(vars, inner_vars), out ++ [inner_out]}

          true ->
            {vars, out ++ [elem]}
        end
      end)

    {vars, List.to_tuple(out)}
  end

  def field_to_var(%Lethe.Query{fields: fields}, field) do
    if Map.has_key?(fields, field) do
      field_num = Map.get fields, field
      :"$#{field_num}"
    else
      raise ArgumentError, "field '#{field}' not found in: #{inspect fields}"
    end
  end

  ###################
  ## Where clauses ##
  ###################

  def where_raw(%__MODULE__.Query{ops: ops} = query, raw) do
    %{query | ops: ops ++ [raw]}
  end

  @doc """
  Adds a guard to the query. Guards are roughly analogous to `WHERE` clauses in
  SQL, but can operate on all the Elixir data types. Instead of needing to
  write out guards yourself, or suffer through the scary mess defined in
  `Lethe.Ops`, you can instead just write normal Elixir in your `where` calls,
  and Lethe will convert them into guard form. For example:

      # ...
      |> Lethe.where(:field_name * 2 <= 10)
      |> Lethe.where(:field_two == 7 and :field_three != "test")
      # ...

  Lethe `where` expressions are normal Elixir code. Some operators are
  rewritten from Elixir form to Mnesia form at compile time; for example,
  Elixir's `and` operator is rewritten to an `:andalso` Mnesia guard.

  However, Lethe `where` expressions differ from normal Elixir expressions in
  one major way: You cannot use external variables directly, but instead must
  pin them, or, in other words, use the `^` operator. For example:

      i = 0
      # ...
      # Note the pin (`^`) operator. This wil not work as expected otherwise,
      # and may return invalid results
      |> Lethe.where(:value == ^i * 2)

  A list of all available functions can be found here:
  https://erlang.org/doc/apps/erts/match_spec.html#grammar
  """
  @spec where(__MODULE__.Query.t(), expression()) :: __MODULE__.Query.t()
  defmacro where(query, operation) do
    # Rewrite the expression into a form that can be safely quoted, without the
    # compiler yelling at us about it being an invalid AST.
    with {op, args} when is_atom(op) and is_list(args) <- Lethe.AstTransformer.__rewrite_into_quotable_form(operation) do
      # Once the primary op is rewritten, rewrite the args to the primary op as
      # well. This will recursively ensure the validity of all expressions.
      args = Enum.map args, &Lethe.AstTransformer.__rewrite_into_quotable_form/1
      quote do
        # Rewrite the op into an Mnesia-guard-friendly form as needed.
        rewritten_op = Lethe.AstTransformer.__rewrite_op unquote(op)
        # Transform all the args as well.
        transformed_args = Enum.map unquote(args), &Lethe.AstTransformer.__transform_op(unquote(query), &1)
        # Apply the relevant op functions to transform the expression into its
        # final Mnesia guard form.
        guard = apply Ops, rewritten_op, transformed_args
        # Add it to the query's ops.
        %{unquote(query) | ops: unquote(query).ops ++ [guard]}
      end
    end
  end

  defmodule AstTransformer do
    # More/less all of these functions recurse so that everything can be
    # properly processed.

    alias Lethe.Ops

    def __rewrite_into_quotable_form({:^, _, [{var, meta, nil}]}) do
      # When we're passed a pinned variable, rewrite it into the literal AST
      # for the variable, so that it gets used correctly
      quote do
        unquote({var, meta, nil})
      end
    end
    def __rewrite_into_quotable_form({:&, _meta, [atom]}) do
      # When we're passed an &variable, rewrite it into the literal atom
      quote do
        unquote(String.to_atom("__lethe_literal_" <> Atom.to_string(atom)))
      end
    end
    def __rewrite_into_quotable_form({op, _, args}) when is_list(args) do
      # When we run into something that has args, we need to rewrite all of
      # them into quotable form so that they can be used properly.
      {op, __MODULE__.__rewrite_args(args)}
    end
    def __rewrite_into_quotable_form(op), do: op

    def __rewrite_args(args) when is_list(args), do: Enum.map(args, &Lethe.AstTransformer.__rewrite_into_quotable_form/1)
    def __rewrite_args(nil), do: nil

    def __transform_op(query, {op, args}) when is_list(args) do
      # Transform ops from Elixir form into Mnesia guard form where needed.
      apply Ops, __MODULE__.__rewrite_op(op), Enum.map(args, &__MODULE__.__transform_op(query, &1))
    end
    def __transform_op(_, op), do: op

    def __rewrite_op(op) when is_atom(op) do
      case op do
        :"<=" -> :"=<"
        :and -> :andalso
        :or -> :orelse
        _ -> op
      end
    end
  end
end

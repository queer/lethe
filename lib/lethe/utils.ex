defmodule Lethe.Utils do
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

defmodule Persist.Utils do
  def lookup_insert(table, key, new_value) do
    case :dets.lookup(table, key) do
      [{^key, value}] ->
        value
      [] ->
        true = :dets.insert_new(table, {key, new_value})
        new_value
    end
  end
end

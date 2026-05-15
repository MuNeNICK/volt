defmodule Volt.JS.DefineRewriter do
  @moduledoc """
  Rewrite compile-time define expressions in JavaScript source using AST positions.

  This handles dotted member expressions such as `import.meta.env.MODE` and
  `process.env.NODE_ENV`. It intentionally does not rewrite arbitrary bare
  identifiers; that requires scope-aware analysis to avoid changing bindings or
  object property keys.
  """

  @spec rewrite(String.t(), String.t(), map()) :: {:ok, String.t()} | {:error, term()}
  def rewrite(source, _filename, define) when define == %{}, do: {:ok, source}

  def rewrite(source, filename, define) do
    case OXC.parse(source, filename) do
      {:ok, ast} ->
        patches = collect_define_patches(ast, define)
        {:ok, if(patches == [], do: source, else: OXC.patch_string(source, patches))}

      {:error, _} = error ->
        error
    end
  end

  defp collect_define_patches(ast, define) do
    {_ast, patches} =
      OXC.postwalk(ast, [], fn
        %{type: :member_expression, computed: false} = node, patches ->
          {node, maybe_add_define_patch(node, patches, Map.get(define, member_path(node)))}

        node, patches ->
          {node, patches}
      end)

    remove_nested_patches(patches)
  end

  defp maybe_add_define_patch(%{start: start, end: finish}, patches, replacement)
       when is_integer(start) and is_integer(finish) and is_binary(replacement) do
    [%{start: start, end: finish, change: replacement} | patches]
  end

  defp maybe_add_define_patch(_node, patches, _replacement), do: patches

  defp member_path(%{
         type: :member_expression,
         computed: false,
         object: object,
         property: property
       }) do
    with object_path when is_binary(object_path) <- member_path(object),
         %{type: :identifier, name: property_name} when is_binary(property_name) <- property do
      object_path <> "." <> property_name
    else
      _ -> nil
    end
  end

  defp member_path(%{type: :meta_property, meta: %{name: "import"}, property: %{name: "meta"}}) do
    "import.meta"
  end

  defp member_path(%{type: :identifier, name: name}) when is_binary(name), do: name
  defp member_path(_node), do: nil

  defp remove_nested_patches(patches) do
    patches
    |> Enum.sort_by(fn %{start: start, end: finish} -> {start, -(finish - start)} end)
    |> Enum.reduce([], fn patch, acc ->
      if Enum.any?(acc, &contains_patch?(&1, patch)) do
        acc
      else
        [patch | acc]
      end
    end)
  end

  defp contains_patch?(outer, inner) do
    outer.start <= inner.start and outer.end >= inner.end
  end
end

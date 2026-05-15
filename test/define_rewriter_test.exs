defmodule Volt.JS.DefineRewriterTest do
  use ExUnit.Case, async: true

  test "rewrites import.meta.env member expressions" do
    source = "console.log(import.meta.env.MODE, import.meta.env.DEV)"

    assert {:ok, code} =
             Volt.JS.DefineRewriter.rewrite(source, "app.ts", %{
               "import.meta.env.MODE" => ~s("development"),
               "import.meta.env.DEV" => "true"
             })

    assert code == ~s|console.log("development", true)|
  end

  test "rewrites process.env.NODE_ENV member expressions" do
    source = "if (process.env.NODE_ENV === 'development') console.log('dev')"

    assert {:ok, code} =
             Volt.JS.DefineRewriter.rewrite(source, "app.ts", %{
               "process.env.NODE_ENV" => ~s("development")
             })

    assert code == ~s|if ("development" === 'development') console.log('dev')|
  end

  test "does not rewrite bare identifiers" do
    source = "const flag = __VUE_OPTIONS_API__"

    assert {:ok, ^source} =
             Volt.JS.DefineRewriter.rewrite(source, "app.ts", %{
               "__VUE_OPTIONS_API__" => "true"
             })
  end
end

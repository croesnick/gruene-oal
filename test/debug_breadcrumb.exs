defmodule DebugBreadcrumb do
  {:ok, html} = File.read("test/fixtures/gemeinde.html")
  {:ok, doc} = Floki.parse_document(html)
  
  IO.puts("=== All .breadcrumb a ===")
  IO.inspect(Floki.find(doc, ".breadcrumb a"))
  
  IO.puts("\n=== Manual extraction ===")
  results = Floki.find(doc, ".breadcrumb")
  IO.inspect(results)
end
mix run test/debug_breadcrumb.exs
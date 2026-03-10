defmodule DebugActual do
  fixtures = [
    {"kreis.html", "test/fixtures/kreis.html"},
    {"gemeinde.html", "test/fixtures/gemeinde.html"},
    {"stimmbezirk.html", "test/fixtures/stimmbezirk.html"}
  ]
  
  for {name, path} <- fixtures do
    {:ok, html} = File.read(path)
    {:ok, doc} = Floki.parse_document(html)
    
    IO.puts("\n=== #{name} ===")
    IO.inspect("Breadcrumb selector": not(span) > a:")
    IO.inspect(Floki.find(doc, ".breadcrumb :not(span) > a"))
    
    IO.inspect("\nAll breadcrumb links:")
    IO.inspect(Floki.find(doc, ".breadcrumb a"))
    
    IO.inspect("\nDirect approach (get all a, filter for non-empty):")
    links = Floki.find(doc, ".breadcrumb a")
    non_empty = Enum.filter(links, fn
      [{_, _, data}] when is_list(data) and length(data) > 0 -> data
      _ -> false
    end)
    IO.inspect(non_empty)
  end
end
mix run test/debug_actual.exs
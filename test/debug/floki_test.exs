defmodule DebugFlokiTest do
  html = File.read!("test/fixtures/gemeinde.html")
  {:ok, doc} = Floki.parse_document(html)
  
  IO.puts("\n=== Direct breadcrumb selector ===")
  breadcrumb = Floki.find(doc, ".breadcrumb")
  IO.inspect(breadcrumb)
  
  IO.puts("\n=== All a in breadcrumb ===")
  links = Floki.find(doc, ".breadcrumb a")
  IO.inspect(links)
  
  IO.puts("\n=== Last link only ===")
  if Enum.empty?(links) do
    IO.puts("No links found")
  else
    last = List.last(links)
    IO.inspect(last)
  end
end

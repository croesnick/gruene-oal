defmodule DebugBreadcrumbTrace do
  html = File.read!("test/fixtures/gemeinde.html")
  {:ok, doc} = Floki.parse_document(html)
  
  IO.puts("\n=== Parsing breadcrumb ===")
  parent_candidates = 
    doc
    |> Floki.find(".breadcrumb > ul > li")
    |> Enum.map(fn li -> 
      IO.puts("Processing li: ")
      IO.inspect(li)
      
      text = Floki.findall_first(li, "*")
      IO.puts("First child element:")
      IO.inspect(text)
      
      a = Floki.findall_first(li, "a")
      IO.puts("a element:")
      IO.inspect(a)
      
      a_list = Floki.findall(li, "a")
      IO.puts("All a elements:")
      IO.inspect(a_list)
      
      a_not_span = Floki.findall(li, "a:not(span)")
      IO.puts("a:not(span):")
      IO.inspect(a_not_span)
      
      if a do
        href = Floki.attribute(a, "href")
        IO.puts("href:")
        IO.inspect(href)
        %{href: href, text: a}
      else
        IO.puts("NULL - no a found")
        nil
      end
    end)
    |> Enum.filter(& &1)
  
  IO.inspect("\n=== Parent candidates ===")
  IO.inspect(parent_candidates)
  IO.inspect("Last element: ")
  IO.inspect(Enum.at(parent_candidates, -1))
end

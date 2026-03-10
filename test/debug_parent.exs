defmodule DebugParentTest do
  html = File.read!("test/fixtures/gemeinde.html")
  {:ok, doc} = Floki.parse_document(html)
  
  IO.puts("=== Get last breadcrumb a ===")
  links = Floki.find(doc, ".breadcrumb a")
  last = List.last(links)
  
  IO.inspect("Last element:")
  IO.inspect(last)
  
  IO.puts("\n=== Get href ===")
  href = Floki.attribute(last, "href")
  IO.inspect(href)
  
  IO.puts("\n=== Check if href is list ===")
  IO.inspect(is_list(href))
  
  IO.puts("\n=== Check what happens with empty breadcrumb ===")
  
  # Try with empty breadcrumb
  html_empty = """
  <div class="x"><ul class="breadcrumb"><li><span>test</span></li></ul></div>
  """
  {:ok, doc2} = Floki.parse_document(html_empty)
  links2 = Floki.find(doc2, ".breadcrumb a")
  IO.inspect("Empty breadcrumb links:")
  IO.inspect(links2)
end

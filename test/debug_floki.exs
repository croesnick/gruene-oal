defmodule DebugFloki do
  html = """
  <ul class="breadcrumb">
    <li><a href="ergebnisse_kreis_09777000.html">Landkreis Ostallgäu</a></li>
    <li><span>Stadt Füssen</span></li>
  </ul>
  """
  
  {:ok, doc} = Floki.parse_document(html)
  
  IO.puts("=== All a in breadcrumb ===")
  IO.inspect(Floki.find(doc, ".breadcrumb a"))
  
  IO.puts("\n=== All direct children ===")
  IO.inspect(Floki.find(doc, ".breadcrumb > ul > li > a"))
  
  IO.puts("\n=== All li elements ===")
  IO.inspect(Floki.find(doc, ".breadcrumb > ul > li"))
  
  IO.puts("\n=== Direct linklist a elements ===")
  IO.inspect(Floki.find(doc, ".dropdown__content ul.linklist > li > a"))
end

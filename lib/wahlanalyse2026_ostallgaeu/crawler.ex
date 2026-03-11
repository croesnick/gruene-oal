defmodule Wahlanalyse2026Ostallgaeu.Crawler do
  @moduledoc """
  URL Crawler for discovering the election website hierarchy.

  Crawls the election website starting from the root URL and discovers
  all areas (Kreis, Gemeinden, Verwaltungsgemeinschaften, Stimmbezirke, Briefwahlbezirke).

  Does NOT download the full data - only discovers URLs.
  """

  @base_url "https://wahlen.osrz-akdb.de/sw-p/777000/4/20260308/kreistagswahl_kreis/"

  @doc """
  Fetches HTML content from a given URL.

  Returns the HTML string on success, or an error tuple on failure.
  """
  @spec fetch_page(String.t()) :: String.t() | {:error, term()}
  def fetch_page(url) when is_binary(url) do
    case Req.get(url, receive_timeout: 30_000) do
      {:ok, %{body: body}} when is_binary(body) ->
        body

      {:ok, %{status: status}} ->
        {:error, {:http_error, status}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Extracts child area URLs from an HTML page.

  Looks for links in the "Untergeordnete Gebiete" section that match
  the election result URL patterns.

  Returns a list of relative URL strings (e.g., "ergebnisse_gemeinde_09777129.html").
  """
  @spec extract_child_urls(String.t()) :: [String.t()]
  def extract_child_urls(html) when is_binary(html) do
    {:ok, document} = Floki.parse_document(html)

    # Find all links that start with 'ergebnisse_' in the child areas section
    # The selector is flexible to handle different nested structures
    document
    |> Floki.find(".dropdown__content a[href^='ergebnisse_']")
    |> Enum.map(fn element ->
      case Floki.attribute(element, "href") do
        [href | _] -> href
        _ -> nil
      end
    end)
    |> Enum.filter(& &1)
  end

  @doc """
  Classifies a URL into its area type.

  ## Examples

      iex> classify_url("ergebnisse_gemeinde_09777129.html")
      :gemeinde

      iex> classify_url("index.html")
      :kreis

  """
  @spec classify_url(String.t()) :: atom()
  def classify_url(url) when is_binary(url) do
    cond do
      String.contains?(url, "gemeinde_09") and not String.contains?(url, "verbandsgemeinde") ->
        :gemeinde

      String.contains?(url, "verbandsgemeinde_") ->
        :verbandsgemeinde

      String.contains?(url, "stimmbezirk_") ->
        :stimmbezirk

      String.contains?(url, "briefwahlbezirk_") ->
        :briefwahlbezirk

      String.contains?(url, "kreis_09") or url == "index.html" ->
        :kreis

      true ->
        :unknown
    end
  end

  @doc """
  Builds a URL tree from HTML content.

  Returns a map where keys are the child URLs and values are empty maps
  (to be populated recursively when crawling deeper).
  """
  @spec build_url_tree(String.t(), String.t()) :: %{String.t() => map()}
  def build_url_tree(html, _base_url) when is_binary(html) do
    child_urls = extract_child_urls(html)

    child_urls
    |> Enum.map(fn url -> {url, %{}} end)
    |> Map.new()
  end

  @doc """
  Crawls the election website starting from the root URL.

  Discovers all areas and returns a map of discovered area IDs to their
  metadata (including type and URL).

  Returns `{:ok, areas_map}` on success, `{:error, reason}` on failure.

  ## Options

    * `:max_depth` - Maximum depth to crawl (default: 3). Use to limit crawling.
    * `:only_discover` - If true, only discovers direct children without recursing.

  ## Example result structure

      %{
        "kreis_09777000" => %{type: :kreis, url: "..."},
        "gemeinde_09777129" => %{type: :gemeinde, url: "..."},
        "stimmbezirk_097771290001" => %{type: :stimmbezirk, url: "..."},
        ...
      }
  """
  @spec crawl_from_root(keyword()) :: {:ok, %{String.t() => map()}} | {:error, term()}
  def crawl_from_root(opts \\ []) do
    max_depth = Keyword.get(opts, :max_depth, 3)
    only_discover = Keyword.get(opts, :only_discover, false)

    case fetch_page(@base_url <> "index.html") do
      {:error, reason} ->
        {:error, reason}

      html when is_binary(html) ->
        areas = crawl_page(html, @base_url, %{}, %{}, max_depth, only_discover)
        {:ok, areas}
    end
  end

  @doc """
  Extracts the area ID from a URL.

  ## Examples

      iex> extract_area_id("ergebnisse_gemeinde_09777129.html")
      "09777129"

      iex> extract_area_id("ergebnisse_stimmbezirk_097771290001.html")
      "097771290001"

  """
  @spec extract_area_id(String.t()) :: String.t() | nil
  def extract_area_id(url) when is_binary(url) do
    case Regex.run(~r/(\d{8,12})\.html$/, url) do
      [_, id] -> id
      _ -> nil
    end
  end

  # Private functions

  defp crawl_page(html, base_url, discovered, visited, depth, only_discover) do
    child_urls = extract_child_urls(html)

    Enum.reduce(child_urls, discovered, fn url, acc ->
      crawl_child(url, base_url, acc, visited, depth, only_discover)
    end)
  end

  defp crawl_child(url, base_url, discovered, visited, depth, only_discover) do
    full_url = base_url <> url

    # Check if we've already visited this URL
    if Map.has_key?(visited, full_url) do
      discovered
    else
      crawl_new_child(url, base_url, discovered, visited, full_url, depth, only_discover)
    end
  end

  defp crawl_new_child(url, base_url, discovered, visited, full_url, depth, only_discover) do
    area_id = extract_area_id(url)
    area_type = classify_url(url)

    if area_id && area_type != :unknown do
      do_crawl_child(
        area_id,
        area_type,
        base_url,
        discovered,
        visited,
        full_url,
        depth,
        only_discover
      )
    else
      discovered
    end
  end

  defp do_crawl_child(
         area_id,
         area_type,
         base_url,
         discovered,
         visited,
         full_url,
         depth,
         only_discover
       ) do
    key = area_key(area_type, area_id)

    # Add to discovered
    discovered = Map.put(discovered, key, %{type: area_type, url: full_url})

    # Fetch and crawl children if it's a type that has children and we haven't reached max depth
    should_recurse =
      not only_discover and
        depth > 0 and
        area_type in [:kreis, :gemeinde, :verbandsgemeinde]

    if should_recurse do
      fetch_and_crawl_children(full_url, base_url, discovered, visited, depth, only_discover)
    else
      discovered
    end
  end

  defp fetch_and_crawl_children(full_url, base_url, discovered, visited, depth, only_discover) do
    case fetch_page(full_url) do
      html when is_binary(html) ->
        new_visited = Map.put(visited, full_url, true)
        crawl_page(html, base_url, discovered, new_visited, depth - 1, only_discover)

      {:error, _} ->
        discovered
    end
  end

  defp area_key(:kreis, id), do: "kreis_#{id}"
  defp area_key(:gemeinde, id), do: "gemeinde_#{id}"
  defp area_key(:verbandsgemeinde, id), do: "verbandsgemeinde_#{id}"
  defp area_key(:stimmbezirk, id), do: "stimmbezirk_#{id}"
  defp area_key(:briefwahlbezirk, id), do: "briefwahlbezirk_#{id}"
end

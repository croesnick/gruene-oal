defmodule Mix.Tasks.Download do
  @moduledoc """
  Downloads election data from the 2026 Kreistagswahl and saves as JSON files.
  """

  use Mix.Task

  @moduledoc "Downloads election data from the 2026 Kreistagswahl"

  alias Wahlanalyse2026Ostallgaeu.Area

  def run(_args) do
    # Start the application for Req HTTP client
    Mix.Task.run("app.start")

    IO.puts("Starting download task...")

    case Wahlanalyse2026Ostallgaeu.Crawler.crawl_from_root() do
      {:ok, url_tree} ->
        urls = Map.keys(url_tree)
        IO.puts("Found #{length(urls)} URLs to download")

        create_data_directory()

        Enum.with_index(urls, 1)
        |> Enum.reduce(%{count: 0, success: 0, errors: []}, fn {url, index}, status ->
          handle_download(url, url_tree[url], index, status)
        end)
        |> case do
          stats ->
            IO.puts("\nDownload complete:")
            IO.puts("  Total: #{stats.count}")
            IO.puts("  Success: #{stats.success}")
            if stats.errors != [], do: IO.puts("  Errors: #{length(stats.errors)}")
        end


      {:error, reason} ->
        IO.puts("Error crawling URLs: #{inspect(reason)}")
    end
  end

  defp handle_download(url, %{type: area_type, url: full_url}, index, status) do
    IO.write("\r[#{index}] Downloading #{area_type}: #{url}")

    case fetch_and_parse(area_type, full_url, extract_id(url)) do
      {:ok, area} ->
        filename = get_filename(area_type, area.id)
        save_json(filename, area)
        %{status | success: status.success + 1}

      {:error, reason} ->
        IO.puts("\n  Error: #{inspect(reason)}")
        %{status | errors: status.errors ++ [{url, reason}]}
    end
  end

  defp fetch_and_parse(type, url, id) do
    case Wahlanalyse2026Ostallgaeu.Crawler.fetch_page(url) do
      {:error, reason} ->
        {:error, {:fetch_error, reason}}

      html when is_binary(html) ->
        case parse_html(type, html, id) do
          {:ok, area} ->
            {:ok, area}

          {:error, reason} ->
            {:error, {:parse_error, reason}}
        end
    end
  end

  defp parse_html(:kreis, html, id) do
    with {:ok, document} <- Floki.parse_document(html),
         {:ok, name} <- extract_name(document),
         area <- build_area(document, id, :kreis, name),
         {:ok, area_with_children} <- add_children(area, document) do
      {:ok, area_with_children}
    end
  end

  defp parse_html(:gemeinde, html, id) do
    with {:ok, document} <- Floki.parse_document(html),
         {:ok, name} <- extract_name(document),
         {:ok, parent_id} <- extract_parent_id(document),
         area <- build_area(document, id, :gemeinde, name, parent_id),
         {:ok, area_with_children} <- add_children(area, document) do
      {:ok, area_with_children}
    end
  end

  defp parse_html(:verbandsgemeinde, html, id) do
    with {:ok, document} <- Floki.parse_document(html),
         {:ok, name} <- extract_name(document),
         {:ok, parent_id} <- extract_parent_id(document),
         area <- build_area(document, id, :verbandsgemeinde, name, parent_id),
         {:ok, area_with_children} <- add_children(area, document) do
      {:ok, area_with_children}
    end
  end
  defp parse_html(:stimmbezirk, html, id) do
    with {:ok, document} <- Floki.parse_document(html),
         {:ok, name} <- extract_name(document),
         {:ok, parent_id} <- extract_parent_id(document),
         area <- build_area(document, id, :stimmbezirk, name, parent_id) do
      {:ok, area}
    end
  end

  defp parse_html(:briefwahlbezirk, html, id) do
    with {:ok, document} <- Floki.parse_document(html),
         {:ok, name} <- extract_name(document),
         {:ok, parent_id} <- extract_parent_id(document),
         area <- build_area(document, id, :briefwahlbezirk, name, parent_id) do
      {:ok, area}
    end
  end

  defp build_area(document, id, type, name, parent_id \\ nil) do
    %Area{
      id: id,
      type: type,
      name: name,
      parent_id: parent_id,
      wahlbeteiligung: extract_wahlbeteiligung(document),
      stimmberechtigte: extract_footer_value(document, "Stimmberechtigte"),
      waehler: extract_footer_value(document, "Wähler"),
      ungueltige: extract_footer_value(document, "Ungültige Stimmzettel"),
      gueltige: extract_footer_value(document, "Gültige Stimmen"),
      parteien: extract_parteien(document),
      ergebnis_stand: extract_ergebnis_stand(document)
    }
  end

  defp extract_name(document) do
    case Floki.find(document, ".header-gebiet__name") do
      [{_, _, [name | _]} | _] when is_binary(name) -> {:ok, String.trim(name)}
      _ -> {:error, :name_not_found}
    end
  end

  defp extract_wahlbeteiligung(document) do
    case Floki.find(document, ".js-wahlbeteiligung__number") do
      [element | _] ->
        case Floki.attribute([element], "data-to") do
          [value] -> parse_german_number(value)
          _ -> nil
        end

      _ ->
        nil
    end
  end

  defp extract_footer_value(document, label) do
    document
    |> Floki.find("table.table-stimmen tfoot tr")
    |> Enum.find_value(fn row ->
      case Floki.find(row, "th") do
        [{_, _, [th_text | _]} | _] when is_binary(th_text) ->
          if String.contains?(th_text, label) do
            case Floki.find(row, "td:first-of-type") do
              [td_element | _] ->
                case Floki.attribute([td_element], "data-sort") do
                  [value] -> parse_german_number(value)
                  _ -> nil
                end

              _ ->
                nil
            end
          end

        _ ->
          nil
      end
    end)
  end

  defp extract_parent_id(document) do
    parent_candidates =
      document
      |> Floki.find("ul.breadcrumb > li")
      |> Enum.map(fn li ->
        case Floki.find(li, "> a") do
          [a_element | _] ->
            case Floki.attribute([a_element], "href") do
              [href | _] when is_binary(href) -> href
              _ -> nil
            end

          _ ->
            nil
        end
      end)
      |> Enum.filter(& &1)

    case Enum.at(parent_candidates, -1) do
      nil ->
        {:error, :parent_id_not_found}

      href when is_binary(href) ->
        case extract_id(href) do
          id when is_binary(id) -> {:ok, id}
          _ -> {:error, :parent_id_not_found}
        end
    end
  end

  defp add_children(area, document) do
    child_candidates =
      document
      |> Floki.find(".dropdown__content > ul > li")
      |> Enum.map(fn li ->
        case Floki.find(li, "> a[href^='ergebnisse_']") do
          [a_element | _] ->
            case Floki.attribute([a_element], "href") do
              [href | _] when is_binary(href) ->
                %{href: href}

              _ ->
                nil
            end

          _ ->
            nil
        end
      end)
      |> Enum.filter(& &1)

    children =
      child_candidates
      |> Enum.map(fn %{href: href} -> extract_id(href) end)
      |> Enum.filter(& &1)

    {:ok, %{area | children: children}}
  end

  defp extract_id(key_or_url) do
    # The key can be either "gemeinde_09777129" or a full URL like "...ergebnisse_gemeinde_09777129.html"
    case Regex.run(~r/(\d{8,12})/, key_or_url) do
      [_, id] -> id
      _ -> nil
    end
  end

  defp parse_german_number(nil), do: nil
  defp parse_german_number(""), do: 0

  defp parse_german_number(string) when is_binary(string) do
    string
    |> String.trim()
    |> String.replace(~r/\s|&nbsp;|%/u, "")
    |> do_parse_german_number()
  end

  defp do_parse_german_number(string) do
    # Handle scientific notation like "0E-10", "1E2", "1.5E-2"
    if String.contains?(string, "E") or String.contains?(string, "e") do
      case Float.parse(string) do
        {value, ""} -> value
        {value, _rest} -> value
        :error -> 0.0
      end
    else
      if String.contains?(string, ",") do
        # German format: remove thousands separators (dots), convert comma to dot
        string
        |> String.replace(".", "")
        |> String.replace(",", ".")
        |> String.to_float()
      else
        # No comma - could be English decimal ("70.0") or German thousands ("1.416")
        dot_count = String.graphemes(string) |> Enum.count(&(&1 == "."))

        cond do
          # Multiple dots: German thousands "1.416.311" -> 1416311
          dot_count > 1 ->
            String.replace(string, ".", "")
            |> String.to_integer()

          # Single dot: check if it's German thousands or English decimal
          dot_count == 1 ->
            [before_dot, after_dot] = String.split(string, ".")

            # German thousands: exactly 3 digits after dot, and before is 1-3 digits
            if String.length(after_dot) == 3 and String.length(before_dot) <= 3 do
              String.replace(string, ".", "")
              |> String.to_integer()
            else
              # English decimal: "70.0" -> 70.0
              String.to_float(string)
            end

          # No dot: plain integer
          true ->
            String.to_integer(string)
        end
      end
    end
  end

  defp extract_parteien(document) do
    document
    |> Floki.find("table.table-stimmen tbody tr")
    |> Enum.map(&parse_party_row/1)
    |> Enum.filter(& &1)
  end

  defp parse_party_row(row) do
    with [{_, _, party_content} | _] <- Floki.find(row, "th .partei__name"),
         [{_, _, [short_name | _]} | _] <- Floki.find(party_content, "abbr"),
         full_name when is_binary(full_name) <- get_party_full_name(party_content, short_name),
         [td_stimmen | _] <- Floki.find(row, "td:first-of-type"),
         [td_anteil | _] <- Floki.find(row, "td:nth-of-type(2)"),
         stimmen_value when not is_nil(stimmen_value) <- get_attribute(td_stimmen, "data-sort"),
         anteil_value when not is_nil(anteil_value) <- get_attribute(td_anteil, "data-sort") do
      %{
        name: full_name,
        kurzbezeichnung: short_name,
        stimmen: parse_german_number(stimmen_value),
        anteil: parse_german_number(anteil_value)
      }
    else
      _ ->
        # Try parsing without abbr (for parties without abbreviation like "Die Linke")
        with [{_, _, party_content} | _] <- Floki.find(row, "th .partei__name"),
             [{_, _, [full_name | _]} | _] <- party_content,
             [td_stimmen | _] <- Floki.find(row, "td:first-of-type"),
             [td_anteil | _] <- Floki.find(row, "td:nth-of-type(2)"),
             stimmen_value when not is_nil(stimmen_value) <-
               get_attribute(td_stimmen, "data-sort"),
             anteil_value when not is_nil(anteil_value) <-
               get_attribute(td_anteil, "data-sort") do
          %{
            name: String.trim(full_name),
            kurzbezeichnung: String.trim(full_name),
            stimmen: parse_german_number(stimmen_value),
            anteil: parse_german_number(anteil_value)
          }
        else
          _ -> nil
        end
    end
  end

  defp get_attribute(element, name) do
    case Floki.attribute([element], name) do
      [value | _] -> value
      _ -> nil
    end
  end

  defp get_party_full_name(party_content, short_name) do
    case Floki.attribute(party_content, "abbr", "title") do
      [title | _] -> title
      _ -> short_name
    end
  end

  defp extract_ergebnis_stand(document) do
    case Floki.find(document, ".header-wahl-sub .stand") do
      [{_, _, [text | _]} | _] when is_binary(text) ->
        String.trim(text)

      _ ->
        nil
    end
  end

  defp create_data_directory do
    File.mkdir_p!("data")
  end

  defp get_filename(area_type, id) do
    "#{area_type}_#{id}.json"
  end

  defp save_json(filename, area) do
    path = Path.join("data", filename)
    content = Jason.encode!(area, pretty: true)
    File.write!(path, content)
  end
end

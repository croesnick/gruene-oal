defmodule Wahlanalyse2026Ostallgaeu.Parser do
  @moduledoc """
  HTML Parser for election results from osrz-akdb.de.

  Parses HTML pages for different area types (Kreis, Gemeinde, Stimmbezirk, Briefwahlbezirk)
  and extracts election results including party votes, voter turnout, and area hierarchy.
  """

  alias Wahlanalyse2026Ostallgaeu.Area

  @doc """
  Parses a German number format string to a numeric value.

  German format uses:
  - `.` (dot) as thousands separator
  - `,` (comma) as decimal separator

  ## Examples

      iex> parse_german_number("1.416.311")
      1416311

      iex> parse_german_number("37,3 %")
      37.3

  """
  @spec parse_german_number(String.t() | nil) :: integer() | float() | nil
  def parse_german_number(nil), do: nil

  def parse_german_number(string) when is_binary(string) do
    string
    |> String.trim()
    |> String.replace(~r/\s|&nbsp;|%/u, "")
    |> do_parse_german_number()
  end

  defp do_parse_german_number(""), do: 0

  defp do_parse_german_number(string) do
    # Check for German decimal comma: "37,3" or "1,416"
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
          # e.g., "1.416" -> 1416, "140.424" -> 140424
          if String.length(after_dot) == 3 and String.length(before_dot) <= 3 do
            String.replace(string, ".", "")
            |> String.to_integer()
          else
            # English decimal: "70.0" -> 70.0, "43.68" -> 43.68
            String.to_float(string)
          end

        # No dot: plain integer
        true ->
          String.to_integer(string)
      end
    end
  end

  @doc """
  Parses a Kreis (district) level HTML page.

  Returns `{:ok, %Area{}}` on success or `{:error, reason}` on failure.
  """
  @spec parse_kreis(String.t()) :: {:ok, Area.t()} | {:error, term()}
  def parse_kreis(html) when is_binary(html) do
    parse_area(html, :kreis, "09777000")
  end

  @doc """
  Parses a Gemeinde (municipality) level HTML page.

  The ID must be provided since it's not embedded in the HTML.

  Returns `{:ok, %Area{}}` on success or `{:error, reason}` on failure.
  """
  @spec parse_gemeinde(String.t(), String.t()) :: {:ok, Area.t()} | {:error, term()}
  def parse_gemeinde(html, id) when is_binary(html) and is_binary(id) do
    {:ok, document} = Floki.parse_document(html)

    with {:ok, name} <- extract_name(document),
         {:ok, parent_id} <- extract_parent_id(document) do
      area =
        build_area(document, id, :gemeinde, name, parent_id)
        |> add_children(document)

      {:ok, area}
    end
  end

  @doc """
  Parses a Stimmbezirk (polling station) level HTML page.

  The ID must be provided since it's not embedded in the HTML.

  Returns `{:ok, %Area{}}` on success or `{:error, reason}` on failure.
  """
  @spec parse_stimmbezirk(String.t(), String.t()) :: {:ok, Area.t()} | {:error, term()}
  def parse_stimmbezirk(html, id) when is_binary(html) and is_binary(id) do
    parse_stimmbezirk_or_briefwahl(html, :stimmbezirk, id)
  end

  @doc """
  Parses a Briefwahlbezirk (mail-in ballot) level HTML page.

  The ID must be provided since it's not embedded in the HTML.

  Returns `{:ok, %Area{}}` on success or `{:error, reason}` on failure.
  """
  @spec parse_briefwahlbezirk(String.t(), String.t()) :: {:ok, Area.t()} | {:error, term()}
  def parse_briefwahlbezirk(html, id) when is_binary(html) and is_binary(id) do
    parse_stimmbezirk_or_briefwahl(html, :briefwahlbezirk, id)
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
    # Match the numeric ID pattern in URLs
    case Regex.run(~r/(\d{8,12})\.html$/, url) do
      [_, id] -> id
      _ -> nil
    end
  end

  # Private functions

  defp parse_stimmbezirk_or_briefwahl(html, type, id) do
    {:ok, document} = Floki.parse_document(html)

    with {:ok, name} <- extract_name(document),
         {:ok, parent_id} <- extract_parent_id(document) do
      area = build_area(document, id, type, name, parent_id)
      {:ok, area}
    end
  end

  defp parse_area(html, type, default_id) do
    {:ok, document} = Floki.parse_document(html)

    with {:ok, name} <- extract_name(document) do
      area =
        build_area(document, default_id, type, name, nil)
        |> add_children(document)

      {:ok, area}
    end
  end

  defp build_area(document, id, type, name, parent_id) do
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
      [{_, _, [name | _]} | _] when is_binary(name) ->
        {:ok, String.trim(name)}

      _ ->
        {:error, :name_not_found}
    end
  end

  defp extract_wahlbeteiligung(document) do
    case Floki.find(document, ".js-wahlbeteiligung__number") do
      [element | _] ->
        case Floki.attribute([element], "data-to") do
          [value] -> parse_german_number(value)
          _ -> nil
        end

          _ -> nil
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
  defp extract_parent_id(document) do
    # Look for parent URL in breadcrumb (the LAST link before current area)
    # DOM structure: .breadcrumb > ul > li > a (text) + li > span (empty)
    parent_candidates =
      document
      |> Floki.find("ul.breadcrumb > li")
      |> Enum.map(fn li ->
        # Get direct a child (skip span)
        case Floki.find(li, "> a") do
          [a_element | _] ->
            case Floki.attribute([a_element], "href") do
              [href | _] when is_binary(href) -> href
              _ -> nil
            end
          _ -> nil
        end
      end)
      |> Enum.filter(& &1)

    case Enum.at(parent_candidates, -1) do
      nil ->
        {:error, :parent_id_not_found}

      href when is_binary(href) ->
        case extract_area_id(href) do
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
        # Get direct a child with href
        case Floki.find(li, "> a[href^='ergebnisse_']") do
          [a_element | _] ->
            case Floki.attribute([a_element], "href") do
              [href | _] when is_binary(href) ->
                text = Floki.text(a_element)
                %{href: href, text: text}
              _ -> nil
            end
          _ -> nil
        end
      end)
      |> Enum.filter(& &1)

    children =
      child_candidates
      |> Enum.map(fn %{href: href} -> extract_child_id(href) end)
      |> Enum.filter(& &1)

    %{area | children: children}
  end

  defp extract_child_id(href) do
    # Extract "gemeinde_09777129" from "ergebnisse_gemeinde_09777129.html"
    case Regex.run(~r/ergebnisse_(.+)\.html$/, href) do
      [_, child_id] -> child_id
      _ -> nil
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
end

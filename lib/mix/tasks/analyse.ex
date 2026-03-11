defmodule Mix.Tasks.Analyse do
  @moduledoc """
  Analyzes election data and outputs a summary of party performance.
  """

  use Mix.Task

  @moduledoc "Analyzes election data and outputs party rankings"

  alias Wahlanalyse2026Ostallgaeu.Analysis

  def run(_args) do
    IO.puts("")
    areas = Analysis.load_all_data()

    if areas == [] do
      IO.puts("No data found. Please run 'mix download' first.")
    else
      IO.puts("Loaded #{length(areas)} areas")

      parties = ["GRÜNE", "AfD"]
      areas_by_id = Map.new(areas, fn area -> {area.id, area} end)

      Enum.each(parties, fn party ->
        analyze_party(areas, areas_by_id, party)
      end)

      print_summary(areas)
    end

    :ok
  end

  defp analyze_party(areas, areas_by_id, party_name) do
    IO.puts("Top 10 #{party_name}-Gebiete")
    IO.puts("-" <> String.duplicate("-", 24))

    party_short =
      case party_name do
        "GRÜNE" -> "GRÜNE"
        "AfD" -> "AfD"
        _ -> party_name
      end

    short_name =
      if party_short != party_name do
        party_short
      else
        party_name
      end

    ranked_areas = Analysis.rank_by_party(areas, short_name)

    if ranked_areas == [] do
      IO.puts("  No data for #{party_name}")
    else
      ranked_areas
      |> Enum.take(10)
      |> Enum.with_index(1)
      |> Enum.each(fn {area, index} ->
        anteil = Wahlanalyse2026Ostallgaeu.Area.get_party(area, short_name).anteil
        _formatted_anteil = Float.round(anteil, 1)
        display_name = get_display_name(area, areas_by_id, short_name, anteil)
        IO.puts("  #{index}. #{display_name}")
      end)
    end

    IO.puts("")
  end

  defp print_summary(areas) do
    IO.puts("Ueber Kreisdurchschnitt")
    IO.puts("-" <> String.duplicate("-", 30))

    parties = ["GRÜNE", "AfD"]

    Enum.each(parties, fn party_name ->
      short_name =
        if party_name == "GRÜNE" do
          "GRÜNE"
        else
          "AfD"
        end

      above_areas = Analysis.above_average_areas(areas, short_name)
      above_count = length(above_areas)

      IO.puts("  #{party_name}: #{above_count} von #{length(areas)} Gebiete")
    end)

    IO.puts("")
  end

  defp get_display_name(area, areas_by_id, party_name, anteil) do
    formatted_anteil = Float.round(anteil, 1)

    if area.type in [:stimmbezirk, :briefwahlbezirk] and area.parent_id do
      parent = Map.get(areas_by_id, area.parent_id)
      mail_icon = if area.type == :briefwahlbezirk, do: "✉️ ", else: ""

      if parent do
        formatted_parent = clean_municipality_name(parent.name)
        "#{mail_icon}#{formatted_parent} / #{area.name} (ID: #{area.id}): #{party_name} #{formatted_anteil}%"
      else
        "#{mail_icon}#{area.name} (ID: #{area.id}): #{party_name} #{formatted_anteil}%"
      end
    else
      "#{clean_municipality_name(area.name)} (ID: #{area.id}): #{party_name} #{formatted_anteil}%"
    end
  end

  defp clean_municipality_name(name) do
    # Remove ID prefix like "09777139 - " and type prefix like "Stadt " / "Markt " / "Gemeinde "
    name
    |> String.replace(~r/^\d+\s*-\s*/, "")
    |> String.replace_prefix("Stadt ", "")
    |> String.replace_prefix("Markt ", "")
    |> String.replace_prefix("Gemeinde ", "")
  end
end

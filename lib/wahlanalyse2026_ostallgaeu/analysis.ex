defmodule Wahlanalyse2026Ostallgaeu.Analysis do
  @moduledoc """
  Analysis module for electoral data.

  Provides functions to analyze election results across areas,
  including ranking areas by party performance and finding areas
  above/below the Kreis average.
  """

  alias Wahlanalyse2026Ostallgaeu.Area

  @doc """
  Loads all JSON data files from the data/ directory.

  Returns a list of Area structs parsed from the JSON files.
  Returns an empty list if the directory doesn't exist or is empty.
  """
  @spec load_all_data() :: [Area.t()]
  def load_all_data do
    data_dir = Path.join(File.cwd!(), "data")

    case File.ls(data_dir) do
      {:ok, files} ->
        files
        |> Enum.filter(&String.ends_with?(&1, ".json"))
        |> Enum.map(&load_area(data_dir, &1))
        |> Enum.filter(& &1)

      {:error, _} ->
        []
    end
  end

  @doc """
  Gets the Kreis-level average (anteil) for a specific party.

  Returns the anteil value from the kreis area in the list.
  Returns nil if no kreis area is found or if the party is not present.

  ## Examples

      iex> areas = [kreis_area(), gemeinde_area()]
      iex> Analysis.get_kreis_average(areas, "CSU")
      43.7
  """
  @spec get_kreis_average([Area.t()], String.t()) :: float() | nil
  def get_kreis_average(areas, party_kurzbezeichnung)
      when is_list(areas) and is_binary(party_kurzbezeichnung) do
    case find_kreis(areas) do
      nil -> nil
      kreis -> get_party_anteil(kreis, party_kurzbezeichnung)
    end
  end

  @doc """
  Ranks areas by a specific party's percentage (anteil) in descending order.

  Areas that don't have the specified party are excluded from the results.
  The kreis area is included if present and has the party.

  ## Examples

      iex> areas = [gemeinde1(), gemeinde2(), gemeinde3()]
      iex> Analysis.rank_by_party(areas, "CSU")
      [%Area{name: "Gemeinde mit highest CSU"}, ...]
  """
  @spec rank_by_party([Area.t()], String.t()) :: [Area.t()]
  def rank_by_party(areas, party_kurzbezeichnung)
      when is_list(areas) and is_binary(party_kurzbezeichnung) do
    areas
    |> Enum.filter(fn area -> has_party?(area, party_kurzbezeichnung) end)
    |> Enum.sort_by(fn area -> get_party_anteil(area, party_kurzbezeichnung) end, :desc)
  end

  @doc """
  Finds areas that are above the Kreis average for a specific party.

  Returns areas (excluding the kreis itself) where the party's anteil
  is greater than the kreis average. Returns an empty list if no kreis
  is present or if no areas are above average.

  ## Examples

      iex> areas = [kreis_area(), gemeinde_area()]
      iex> Analysis.above_average_areas(areas, "CSU")
      [%Area{name: "Gemeinde above CSU average"}]
  """
  @spec above_average_areas([Area.t()], String.t()) :: [Area.t()]
  def above_average_areas(areas, party_kurzbezeichnung)
      when is_list(areas) and is_binary(party_kurzbezeichnung) do
    case get_kreis_average(areas, party_kurzbezeichnung) do
      nil ->
        []

      average ->
        areas
        |> Enum.reject(&(&1.type == :kreis))
        |> Enum.filter(fn area ->
          anteil = get_party_anteil(area, party_kurzbezeichnung)
          anteil != nil and anteil > average
        end)
    end
  end

  # Private functions

  defp load_area(data_dir, filename) do
    filepath = Path.join(data_dir, filename)

    with {:ok, content} <- File.read(filepath),
         {:ok, data} <- Jason.decode(content) do
      parse_area_from_json(data)
    else
      _ -> nil
    end
  end

  defp parse_area_from_json(data) do
    %Area{
      id: data["id"],
      type: String.to_atom(data["type"]),
      name: data["name"],
      parent_id: data["parent_id"],
      children: data["children"] || [],
      wahlbeteiligung: data["wahlbeteiligung"],
      stimmberechtigte: data["stimmberechtigte"],
      waehler: data["waehler"],
      ungueltige: data["ungueltige"],
      gueltige: data["gueltige"],
      parteien: parse_parteien(data["parteien"] || []),
      ergebnis_stand: data["ergebnis_stand"]
    }
  end

  defp parse_parteien(parteien) do
    Enum.map(parteien, fn party ->
      %{
        name: party["name"],
        kurzbezeichnung: party["kurzbezeichnung"],
        stimmen: party["stimmen"],
        anteil: party["anteil"]
      }
    end)
  end

  defp find_kreis(areas) do
    Enum.find(areas, fn area -> area.type == :kreis end)
  end

  defp has_party?(area, party_kurzbezeichnung) do
    case Area.get_party(area, party_kurzbezeichnung) do
      nil -> false
      _party -> true
    end
  end

  defp get_party_anteil(area, party_kurzbezeichnung) do
    case Area.get_party(area, party_kurzbezeichnung) do
      nil -> nil
      party -> party.anteil
    end
  end
end

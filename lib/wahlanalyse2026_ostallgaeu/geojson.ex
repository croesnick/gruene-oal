defmodule Wahlanalyse2026Ostallgaeu.GeoJSON do
  @moduledoc """
  Handles GeoJSON operations for Ostallgäu municipalities.
  """

  @geojson_path "data/geo/ostallgaeu_gemeinden_wgs84.json"

  @doc """
  Reads GeoJSON data from local file.
  """
  @spec load_local_geojson() :: {:ok, map()} | {:error, String.t()}
  def load_local_geojson do
    case File.read(@geojson_path) do
      {:ok, content} ->
        {:ok, Jason.decode!(content)}

      {:error, error} ->
        {:error, "Failed to read GeoJSON: " <> inspect(error)}
    end
  end

  @doc """
  Filters GeoJSON features for Ostallgäu municipalities (AGS starting with "09777").
  """
  @spec filter_ostallgaeu([map()]) :: [map()]
  def filter_ostallgaeu(features) do
    Enum.filter(features, fn feature ->
      ags = feature["properties"]["ags"]
      ags && String.starts_with?(ags, "09777")
    end)
  end

  @doc """
  Matches GeoJSON features with election data by AGS/Area.id.
  """
  @spec match_with_election_data([map()], [Wahlanalyse2026Ostallgaeu.Area.t()]) :: [
          {map(), Wahlanalyse2026Ostallgaeu.Area.t() | nil}
        ]
  def match_with_election_data(features, election_data) do
    election_map = Map.new(election_data, fn area -> {area.id, area} end)

    Enum.map(features, fn feature ->
      ags = feature["properties"]["ags"]

      case Map.get(election_map, ags) do
        nil -> {feature, nil}
        area -> {feature, area}
      end
    end)
  end

  @doc """
  Generates color based on party percentage using gradient scale.
  """
  @spec calculate_color(float(), String.t()) :: String.t()
  def calculate_color(percentage, "GRÜNE") do
    calculate_gradient_color(percentage, "#ffffff", "#90ee90", "#006400")
  end

  def calculate_color(percentage, "AfD") do
    calculate_gradient_color(percentage, "#ffffff", "#87ceeb", "#00008b")
  end

  defp calculate_gradient_color(percentage, color_0, color_10, color_20) do
    percentage = max(0, min(percentage, 100))

    if percentage <= 10 do
      ratio = percentage / 10.0
      interpolate_color(color_0, color_10, ratio)
    else
      ratio = min((percentage - 10) / 10.0, 1.0)
      interpolate_color(color_10, color_20, ratio)
    end
  end

  defp interpolate_color(color1, color2, ratio) do
    {r1, g1, b1} = parse_hex_color(color1)
    {r2, g2, b2} = parse_hex_color(color2)

    r = round(r1 + (r2 - r1) * ratio)
    g = round(g1 + (g2 - g1) * ratio)
    b = round(b1 + (b2 - b1) * ratio)

    "#" <>
      (Integer.to_string(r, 16) |> String.pad_leading(2, "0") |> String.downcase()) <>
      (Integer.to_string(g, 16) |> String.pad_leading(2, "0") |> String.downcase()) <>
      (Integer.to_string(b, 16) |> String.pad_leading(2, "0") |> String.downcase())
  end

  defp parse_hex_color("#" <> hex) do
    {
      String.to_integer(String.slice(hex, 0, 2), 16),
      String.to_integer(String.slice(hex, 2, 2), 16),
      String.to_integer(String.slice(hex, 4, 2), 16)
    }
  end
end

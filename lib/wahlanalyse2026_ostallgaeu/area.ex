defmodule Wahlanalyse2026Ostallgaeu.Area do
  @moduledoc """
  Struct representing an electoral area (Kreis, Gemeinde, Stimmbezirk, etc.)
  """

  @type area_type :: :kreis | :gemeinde | :verbandsgemeinde | :stimmbezirk | :briefwahlbezirk

  @type t :: %__MODULE__{
          id: String.t(),
          type: area_type(),
          name: String.t(),
          parent_id: String.t() | nil,
          children: [String.t()],
          wahlbeteiligung: float() | nil,
          stimmberechtigte: integer() | nil,
          waehler: integer() | nil,
          ungueltige: integer() | nil,
          gueltige: integer() | nil,
          parteien: [party_result()],
          ergebnis_stand: String.t() | nil
        }

  @type party_result :: %{
          name: String.t(),
          kurzbezeichnung: String.t(),
          stimmen: integer(),
          anteil: float()
        }

  @enforce_keys [:id, :type, :name]
  defstruct [
    :id,
    :type,
    :name,
    parent_id: nil,
    children: [],
    wahlbeteiligung: nil,
    stimmberechtigte: nil,
    waehler: nil,
    ungueltige: nil,
    gueltige: nil,
    parteien: [],
    ergebnis_stand: nil
  ]

  @doc """
  Creates a new Area struct with the given attributes.
  """
  @spec new(keyword()) :: t()
  def new(attrs) when is_list(attrs) do
    struct!(__MODULE__, attrs)
  end

  @doc """
  Adds a child ID to the area's children list.
  """
  @spec add_child(t(), String.t()) :: t()
  def add_child(%__MODULE__{} = area, child_id) when is_binary(child_id) do
    %{area | children: area.children ++ [child_id]}
  end

  @doc """
  Returns the party result for a specific party by short name.
  """
  @spec get_party(t(), String.t()) :: party_result() | nil
  def get_party(%__MODULE__{parteien: parteien}, kurzbezeichnung) do
    Enum.find(parteien, fn party -> party.kurzbezeichnung == kurzbezeichnung end)
  end
end

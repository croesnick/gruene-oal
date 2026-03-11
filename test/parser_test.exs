defmodule Wahlanalyse2026Ostallgaeu.ParserTest do
  use ExUnit.Case, async: true

  alias Wahlanalyse2026Ostallgaeu.Area
  alias Wahlanalyse2026Ostallgaeu.Parser

  describe "parse_german_number/1" do
    test "parses simple integer" do
      assert Parser.parse_german_number("123") == 123
    end

    test "parses integer with thousands separator (dot)" do
      assert Parser.parse_german_number("1.416") == 1416
      assert Parser.parse_german_number("140.424") == 140_424
      assert Parser.parse_german_number("98.383") == 98_383
    end

    test "parses integer with multiple thousands separators" do
      assert Parser.parse_german_number("1.416.311") == 1_416_311
    end

    test "parses percentage with decimal (comma)" do
      assert Parser.parse_german_number("37,3") == 37.3
      assert Parser.parse_german_number("70,0") == 70.0
      assert Parser.parse_german_number("43,7") == 43.7
    end

    test "parses string with percentage sign" do
      assert Parser.parse_german_number("37,3 %") == 37.3
      assert Parser.parse_german_number("70,0%") == 70.0
    end

    test "parses string with non-breaking space and percentage" do
      assert Parser.parse_german_number("43,7&nbsp;%") == 43.7
    end

    test "handles whitespace" do
      assert Parser.parse_german_number("  123  ") == 123
    end

    test "returns 0 for empty string" do
      assert Parser.parse_german_number("") == 0
      assert Parser.parse_german_number("   ") == 0
    end

    test "handles negative numbers" do
      assert Parser.parse_german_number("-4,1") == -4.1
    end

    test "handles scientific notation (0E-10) as zero" do
      assert Parser.parse_german_number("0E-10") == 0.0
    end

    test "handles scientific notation with positive exponent" do
      assert Parser.parse_german_number("1E2") == 100.0
    end

    test "handles scientific notation with negative exponent" do
      assert Parser.parse_german_number("1E-2") == 0.01
    end

    test "handles scientific notation with decimal" do
      assert Parser.parse_german_number("1.5E2") == 150.0
    end
  end

  describe "parse_kreis/1" do
    test "parses Kreis HTML and returns Area struct" do
      html = File.read!("test/fixtures/kreis.html")
      {:ok, area} = Parser.parse_kreis(html)

      assert %Area{} = area
      assert area.id == "09777000"
      assert area.type == :kreis
      assert area.name == "Landkreis Ostallgäu"
      assert area.wahlbeteiligung == 70.0
      assert area.stimmberechtigte == 140_611
      assert area.waehler == 98_383
    end

    test "parses party results" do
      html = File.read!("test/fixtures/kreis.html")
      {:ok, area} = Parser.parse_kreis(html)

      csu = Area.get_party(area, "CSU")
      assert csu.name == "Christlich-Soziale Union in Bayern e.V."
      assert csu.stimmen == 140_424
      assert_in_delta csu.anteil, 43.7, 0.1

      gruene = Area.get_party(area, "GRÜNE")
      assert gruene.name == "BÜNDNIS 90/DIE GRÜNEN"
      assert gruene.stimmen == 46_620
      assert_in_delta gruene.anteil, 14.5, 0.1

      afd = Area.get_party(area, "AfD")
      assert afd.name == "Alternative für Deutschland"
      assert afd.stimmen == 33_306
      assert_in_delta afd.anteil, 10.4, 0.1
    end

    test "extracts child URLs" do
      html = File.read!("test/fixtures/kreis.html")
      {:ok, area} = Parser.parse_kreis(html)

      assert "gemeinde_09777129" in area.children
      assert "gemeinde_09777130" in area.children
      assert "verbandsgemeinde_097775752" in area.children
      assert "verbandsgemeinde_097775770" in area.children
    end
  end

  describe "parse_gemeinde/2" do
    test "parses Gemeinde HTML and returns Area struct" do
      html = File.read!("test/fixtures/gemeinde.html")
      {:ok, area} = Parser.parse_gemeinde(html, "09777129")

      assert %Area{} = area
      assert area.id == "09777129"
      assert area.type == :gemeinde
      assert area.name == "Stadt Füssen"
      assert area.parent_id == "09777000"
      assert area.wahlbeteiligung == 53.3
    end

    test "extracts child URLs including stimmbezirk and briefwahlbezirk" do
      html = File.read!("test/fixtures/gemeinde.html")
      {:ok, area} = Parser.parse_gemeinde(html, "09777129")

      assert "stimmbezirk_097771290001" in area.children
      assert "stimmbezirk_097771290002" in area.children
      assert "briefwahlbezirk_097771290021" in area.children
    end
  end

  describe "parse_stimmbezirk/2" do
    test "parses Stimmbezirk HTML and returns Area struct" do
      html = File.read!("test/fixtures/stimmbezirk.html")
      {:ok, area} = Parser.parse_stimmbezirk(html, "097771290001")

      assert %Area{} = area
      assert area.id == "097771290001"
      assert area.type == :stimmbezirk
      assert area.name == "Rathaus Kommunaler Ordnungsdienst"
      assert area.parent_id == "09777129"
    end

    test "parses party results in stimmbezirk" do
      html = File.read!("test/fixtures/stimmbezirk.html")
      {:ok, area} = Parser.parse_stimmbezirk(html, "097771290001")

      csu = Area.get_party(area, "CSU")
      assert csu.stimmen == 4422
      assert_in_delta csu.anteil, 36.7, 0.1

      gruene = Area.get_party(area, "GRÜNE")
      assert gruene.stimmen == 2459
      assert_in_delta gruene.anteil, 20.4, 0.1

      afd = Area.get_party(area, "AfD")
      assert afd.stimmen == 1961
      assert_in_delta afd.anteil, 16.3, 0.1
    end
  end

  describe "parse_briefwahlbezirk/2" do
    test "parses Briefwahlbezirk same as Stimmbezirk" do
      html = File.read!("test/fixtures/stimmbezirk.html")
      {:ok, area} = Parser.parse_briefwahlbezirk(html, "097771290021")

      assert %Area{} = area
      assert area.type == :briefwahlbezirk
    end
  end

  describe "extract_area_id/1" do
    test "extracts ID from Gemeinde URL" do
      assert Parser.extract_area_id("ergebnisse_gemeinde_09777129.html") == "09777129"
    end

    test "extracts ID from Verbandsgemeinde URL" do
      assert Parser.extract_area_id("ergebnisse_verbandsgemeinde_097775752.html") == "097775752"
    end

    test "extracts ID from Stimmbezirk URL" do
      assert Parser.extract_area_id("ergebnisse_stimmbezirk_097771290001.html") == "097771290001"
    end

    test "extracts ID from Briefwahlbezirk URL" do
      assert Parser.extract_area_id("ergebnisse_briefwahlbezirk_097771290021.html") ==
               "097771290021"
    end
  end
end

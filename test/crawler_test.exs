defmodule Wahlanalyse2026Ostallgaeu.CrawlerTest do
  use ExUnit.Case, async: true

  alias Wahlanalyse2026Ostallgaeu.Crawler

  @base_url "https://wahlen.osrz-akdb.de/sw-p/777000/4/20260308/kreistagswahl_kreis/"

  describe "fetch_page/1" do
    test "fetches HTML from a valid URL" do
      html = Crawler.fetch_page(@base_url <> "index.html")
      assert is_binary(html)
      # The website uses HTML entities like &auml; for German umlauts
      assert String.contains?(html, "Ostallg")
    end

    test "returns error tuple for invalid URL" do
      assert {:error, _} = Crawler.fetch_page("https://invalid.url.that.does.not.exist/test.html")
    end
  end

  describe "extract_child_urls/1" do
    test "extracts child URLs from Kreis HTML" do
      html = File.read!("test/fixtures/kreis.html")
      urls = Crawler.extract_child_urls(html)

      assert is_list(urls)
      assert "ergebnisse_gemeinde_09777129.html" in urls
      assert "ergebnisse_gemeinde_09777130.html" in urls
      assert "ergebnisse_verbandsgemeinde_097775752.html" in urls
      assert "ergebnisse_verbandsgemeinde_097775770.html" in urls
    end

    test "extracts child URLs from Gemeinde HTML including stimmbezirke" do
      html = File.read!("test/fixtures/gemeinde.html")
      urls = Crawler.extract_child_urls(html)

      assert is_list(urls)
      assert "ergebnisse_stimmbezirk_097771290001.html" in urls
      assert "ergebnisse_stimmbezirk_097771290002.html" in urls
      assert "ergebnisse_briefwahlbezirk_097771290021.html" in urls
    end

    test "returns empty list for HTML without children" do
      html = File.read!("test/fixtures/stimmbezirk.html")
      urls = Crawler.extract_child_urls(html)

      assert urls == []
    end
  end

  describe "classify_url/1" do
    test "classifies Gemeinde URL" do
      assert Crawler.classify_url("ergebnisse_gemeinde_09777129.html") == :gemeinde
    end

    test "classifies Verbandsgemeinde URL" do
      assert Crawler.classify_url("ergebnisse_verbandsgemeinde_097775752.html") ==
               :verbandsgemeinde
    end

    test "classifies Stimmbezirk URL" do
      assert Crawler.classify_url("ergebnisse_stimmbezirk_097771290001.html") == :stimmbezirk
    end

    test "classifies Briefwahlbezirk URL" do
      assert Crawler.classify_url("ergebnisse_briefwahlbezirk_097771290021.html") ==
               :briefwahlbezirk
    end

    test "classifies index.html as kreis" do
      assert Crawler.classify_url("index.html") == :kreis
      assert Crawler.classify_url("ergebnisse_kreis_09777000.html") == :kreis
    end

    test "returns :unknown for unrecognized patterns" do
      assert Crawler.classify_url("unknown_file.txt") == :unknown
    end
  end

  describe "build_url_tree/1" do
    test "builds URL tree from HTML with children" do
      html = File.read!("test/fixtures/kreis.html")

      tree = Crawler.build_url_tree(html, @base_url)

      assert %{} = tree
      assert Map.has_key?(tree, "ergebnisse_gemeinde_09777129.html")
      assert Map.has_key?(tree, "ergebnisse_gemeinde_09777130.html")
      assert Map.has_key?(tree, "ergebnisse_verbandsgemeinde_097775752.html")
    end
  end

  describe "crawl_from_root/0" do
    @tag timeout: 120_000
    test "discovers all areas starting from root URL" do
      # This test uses the actual URL - be gentle to the server
      # Use only_discover to limit crawling
      result = Crawler.crawl_from_root(only_discover: true)

      assert {:ok, areas} = result
      assert is_map(areas)

      # Should have discovered some Gemeinden (from Kreis page children)
      gemeinden_count =
        areas
        |> Map.keys()
        |> Enum.count(&String.starts_with?(&1, "gemeinde_"))

      assert gemeinden_count > 0
    end
  end

  describe "extract_area_id/1" do
    test "extracts ID from Gemeinde URL" do
      assert Crawler.extract_area_id("ergebnisse_gemeinde_09777129.html") == "09777129"
    end

    test "extracts ID from Verbandsgemeinde URL" do
      assert Crawler.extract_area_id("ergebnisse_verbandsgemeinde_097775752.html") == "097775752"
    end

    test "extracts ID from Stimmbezirk URL" do
      assert Crawler.extract_area_id("ergebnisse_stimmbezirk_097771290001.html") == "097771290001"
    end

    test "extracts ID from Briefwahlbezirk URL" do
      assert Crawler.extract_area_id("ergebnisse_briefwahlbezirk_097771290021.html") ==
               "097771290021"
    end

    test "extracts ID from Kreis URL" do
      assert Crawler.extract_area_id("ergebnisse_kreis_09777000.html") == "09777000"
    end
  end
end

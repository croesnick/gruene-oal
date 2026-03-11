defmodule DownloadTaskTest do
  use ExUnit.Case

  alias Mix.Tasks.Download

  # describe "extract_parteien/1" do
  #   test "parses parties from kreis fixture" do
  #     html = File.read!("test/fixtures/kreis.html")
  #     {:ok, doc} = Floki.parse_document(html)
  # 
  #     parties = Download.extract_parteien(doc)
  # 
  #     assert is_list(parties)
  #     assert length(parties) > 0
  # 
  #     # Check that CSU party is present
  #     csu = Enum.find(parties, &(&1.kurzbezeichnung == "CSU"))
  #     assert csu != nil
  #     assert csu.name == "Christlich-Soziale Union in Bayern e.V."
  #     assert csu.stimmen == 140_424
  #     assert csu.anteil == 43.7
  # 
  #     # Check that GRÜNE party is present
  #     gruene = Enum.find(parties, &(&1.kurzbezeichnung == "GRÜNE"))
  #     assert gruene != nil
  #     assert gruene.name == "BÜNDNIS 90/DIE GRÜNEN"
  #     assert gruene.stimmen == 46_620
  #     assert gruene.anteil == 14.5
  # 
  #     # Check that AfD party is present
  #     afd = Enum.find(parties, &(&1.kurzbezeichnung == "AfD"))
  #     assert afd != nil
  #     assert afd.name == "Alternative für Deutschland"
  #     assert afd.stimmen == 33_306
  #     assert afd.anteil == 10.4
  # 
  #     # Check that SPD party is present
  #     spd = Enum.find(parties, &(&1.kurzbezeichnung == "SPD"))
  #     assert spd != nil
  #     assert spd.name == "Sozialdemokratische Partei Deutschlands"
  #     assert spd.stimmen > 0
  #     assert spd.anteil > 0
  #   end
  # 
  #   test "parses parties from guteinde fixture" do
  #     html = File.read!("test/fixtures/gemeinde.html")
  #     {:ok, doc} = Floki.parse_document(html)
  # 
  #     parties = Download.extract_parteien(doc)
  # 
  #     assert is_list(parties)
  #     assert length(parties) > 0
  # 
  #     first_party = hd(parties)
  #     assert first_party.name != nil
  #     assert first_party.kurzbezeichnung != nil
  #     assert is_integer(first_party.stimmen) or first_party.stimmen == 0
  #     assert is_float(first_party.anteil) or first_party.anteil == 0
  #   end
  # 
  #   test "parses parties from stimmbezirk fixture" do
  #     html = File.read!("test/fixtures/stimmbezirk.html")
  #     {:ok, doc} = Floki.parse_document(html)
  # 
  #     parties = Download.extract_parteien(doc)
  # 
  #     assert is_list(parties)
  #     # Stimmbezirk may have fewer parties (just representative ones)
  #     assert length(parties) >= 2
  #   end
  # end
  # 
  # describe "extract_ergebnis_stand/1" do
  #   test "extracts election result timestamp from kreis fixture" do
  #     html = File.read!("test/fixtures/kreis.html")
  #     {:ok, doc} = Floki.parse_document(html)
  # 
  #     timestamp = Download.extract_ergebnis_stand(doc)
  # 
  #     # Should return a string with the timestamp
  #     assert timestamp != nil
  #     assert is_binary(timestamp)
  #     assert String.contains?(timestamp, "März")
  #     assert String.contains?(timestamp, "2026")
  #   end
  # 
  #   test "extracts timestamp with multiple lines" do
  #     html = File.read!("test/fixtures/kreis.html")
  #     {:ok, doc} = Floki.parse_document(html)
  # 
  #     timestamp = Download.extract_ergebnis_stand(doc)
  # 
  #     assert timestamp != nil
  #     # The timestamp should contain details like "Ausgezählte Gebiete: 242 von 249"
  #     assert String.contains?(timestamp, "Ausgezählte Gebiete")
  #   end
  # 
  #   test "returns nil when no timestamp found in gemeinde fixture" do
  #     html = File.read!("test/fixtures/gemeinde.html")
  #     {:ok, doc} = Floki.parse_document(html)
  # 
  #     timestamp = Download.extract_ergebnis_stand(doc)
  # 
  #     # Gemeinde fixture may or may not have timestamp depending on HTML structure
  #     # For robustness, we just verify it returns nil or string
  #     assert timestamp == nil or is_binary(timestamp)
  #   end
  # end
  # 
  # describe "build_area/5 integration" do
  #   test "creates area with parsed parties from kreis HTML" do
  #     html = File.read!("test/fixtures/kreis.html")
  #     {:ok, doc} = Floki.parse_document(html)
  # 
  #     area = Download.build_area(doc, "09777000", :kreis, "Landkreis Ostallgäu")
  # 
  #     assert %Wahlanalyse2026Ostallgaeu.Area{} = area
  #     assert area.id == "09777000"
  #     assert area.type == :kreis
  #     assert area.name == "Landkreis Ostallgäu"
  #     assert is_list(area.parteien)
  #     assert length(area.parteien) > 0
  # 
  #     # Verify party data structure
  #     csu = Enum.find(area.parteien, &(&1.kurzbezeichnung == "CSU"))
  #     assert csu != nil
  #     assert is_binary(csu.name)
  #     assert is_integer(csu.stimmen) or csu.stimmen == 0
  #     assert is_float(csu.anteil) or csu.anteil == 0
  #   end
  # 
  #   test "creates area with ergebnis_stand from HTML" do
  #     html = File.read!("test/fixtures/kreis.html")
  #     {:ok, doc} = Floki.parse_document(html)
  # 
  #     area = Download.build_area(doc, "09777000", :kreis, "Landkreis Ostallgäu")
  # 
  #     # Verify ergebnis_stand is present
  #     assert area.ergebnis_stand != nil
  #     assert is_binary(area.ergebnis_stand)
  #     assert String.length(area.ergebnis_stand) > 0
  #   end
  # end

  # describe "extract_ergebnis_stand/1" do
  #   test "extracts election result timestamp from kreis fixture" do
  #     html = File.read!("test/fixtures/kreis.html")
  #     {:ok, doc} = Floki.parse_document(html)
  # 
  #     timestamp = Download.extract_ergebnis_stand(doc)
  # 
  #     # Should return a string with the timestamp
  #     assert timestamp != nil
  #     assert is_binary(timestamp)
  #     assert String.contains?(timestamp, "März")
  #     assert String.contains?(timestamp, "2026")
  #   end
  # 
  #   test "extracts timestamp with multiple lines" do
  #     html = File.read!("test/fixtures/kreis.html")
  #     {:ok, doc} = Floki.parse_document(html)
  # 
  #     timestamp = Download.extract_ergebnis_stand(doc)
  # 
  #     assert timestamp != nil
  #     # The timestamp should contain details like "Ausgezählte Gebiete: 242 von 249"
  #     assert String.contains?(timestamp, "Ausgezählte Gebiete")
  #   end
  # 
  #   test "returns nil when no timestamp found in gemeinde fixture" do
  #     html = File.read!("test/fixtures/gemeinde.html")
  #     {:ok, doc} = Floki.parse_document(html)
  # 
  #     timestamp = Download.extract_ergebnis_stand(doc)
  # 
  #     # Gemeinde fixture may or may not have timestamp depending on HTML structure
  #     # For robustness, we just verify it returns nil or string
  #     assert timestamp == nil or is_binary(timestamp)
  #   end
  # end
  # 
  # describe "build_area/5 integration" do
  #   test "creates area with parsed parties from kreis HTML" do
  #     html = File.read!("test/fixtures/kreis.html")
  #     {:ok, doc} = Floki.parse_document(html)
  # 
  #     area = Download.build_area(doc, "09777000", :kreis, "Landkreis Ostallgäu")
  # 
  #     assert %Wahlanalyse2026Ostallgaeu.Area{} = area
  #     assert area.id == "09777000"
  #     assert area.type == :kreis
  #     assert area.name == "Landkreis Ostallgäu"
  #     assert is_list(area.parteien)
  #     assert length(area.parteien) > 0
  # 
  #     # Verify party data structure
  #     csu = Enum.find(area.parteien, &(&1.kurzbezeichnung == "CSU"))
  #     assert csu != nil
  #     assert is_binary(csu.name)
  #     assert is_integer(csu.stimmen) or csu.stimmen == 0
  #     assert is_float(csu.anteil) or csu.anteil == 0
  #   end
  # 
  #   test "creates area with ergebnis_stand from HTML" do
  #     html = File.read!("test/fixtures/kreis.html")
  #     {:ok, doc} = Floki.parse_document(html)
  # 
  #     area = Download.build_area(doc, "09777000", :kreis, "Landkreis Ostallgäu")
  # 
  #     # Verify ergebnis_stand is present
  #     assert area.ergebnis_stand != nil
  #     assert is_binary(area.ergebnis_stand)
  #     assert String.length(area.ergebnis_stand) > 0
  #   end
  # end
end

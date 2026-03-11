defmodule Mix.Tasks.Validate do
  @moduledoc """
  Validates the integrity of election data by checking vote counts and percentages.
  """

  use Mix.Task

  @moduledoc "Validates election data integrity"

  alias Wahlanalyse2026Ostallgaeu.Analysis

  # Percentage tolerance (0.1%)
  @tolerance 0.1

  def run(_args) do
    IO.puts("")
    IO.puts("Data Validation Report")
    IO.puts("=" <> String.duplicate("=", 44))

    areas = Analysis.load_all_data()

    if areas == [] do
      IO.puts("No data found. Please run 'mix download' first.")
    else
      IO.puts("Total areas: #{length(areas)}")

      # Calculate vote count check
      vote_check = calculate_vote_check(areas)
      IO.puts("")
      IO.puts("Vote Count Check:")
      IO.puts("-" <> String.duplicate("-", 8))
      IO.puts("  Passed: #{vote_check.passed} areas (sum of party votes ≈ gueltige)")
      IO.puts("  Failed: #{vote_check.failed} areas (significant discrepancy)")

      # Calculate percentage check (INDEPENDENT of vote sum check)
      percentage_check = calculate_percentage_check(areas)
      IO.puts("")
      IO.puts("Percentage Check (anteil = stimmen / gueltige * 100):")
      IO.puts("-" <> String.duplicate("-", 8))
      IO.puts("  Passed: #{percentage_check.passed} areas")
      IO.puts("  Failed: #{percentage_check.failed} areas")

      # Show details of failures
      IO.puts("")
      IO.puts("Details of failures:")
      IO.puts("-" <> String.duplicate("-", 16))

      # Handle vote count failures
      vote_failures =
        Enum.filter(areas, fn area ->
          is_valid_area?(area) and not check_vote_sum(area)
        end)

      vote_checknos =
        Enum.map(vote_failures, fn area ->
          {sum_votes, gueltige} = calc_stats(area)
          {:vote, "Sum: #{sum_votes}, Gueltige: #{gueltige}"}
        end)

      format_failures(vote_failures, vote_checknos, :vote)

      # Handle percentage failures (INDEPENDENT of vote sum check)
      percentage_failures =
        Enum.filter(areas, fn area ->
          is_valid_area?(area) and not check_percentage(area)
        end)

      percentage_checknos =
        Enum.map(percentage_failures, fn area ->
          # Find first failing party
          failing_party =
            Enum.find_value(area.parteien, fn p ->
              expected = (p.stimmen / area.gueltige * 100) |> Float.round(1)

              if abs(p.anteil - expected) > @tolerance do
                {p, expected}
              else
                nil
              end
            end)

          if failing_party do
            party = elem(failing_party, 0)
            expected = elem(failing_party, 1)
            diff = Float.round(abs(party.anteil - expected), 1)

            {:percentage,
             "Party #{party.name}: #{party.anteil}% (expected: #{expected}%, diff: #{diff}%)"}
          else
            ""
          end
        end)

      # Show first 10 percentage failures
      Enum.filter(percentage_checknos, &(&1 != ""))
      |> Enum.take(10)
      |> Enum.with_index(1)
      |> Enum.each(fn {check_no, index} ->
        IO.puts("  #{index}. #{elem(check_no, 1)}")
      end)

      if length(percentage_checknos) - Enum.count(Enum.filter(percentage_checknos, &(&1 == ""))) > 10 do
        IO.puts("  ... and #{length(percentage_checknos) - 10} more")
      end

      # Show example calculations for first 3 areas
      IO.puts("")
      IO.puts("Example calculations (first 3 areas):")
      IO.puts("-" <> String.duplicate("-", 8))

      areas
      |> Enum.filter(fn area -> is_valid_area?(area) end)
      |> Enum.take(3)
      |> Enum.each(fn area ->
        IO.puts("  #{area.name} (#{String.slice(area.parent_id, 0, 6)}):")

        area.parteien
        |> Enum.filter(fn p ->
          Map.has_key?(p, :anteil) and is_float(p.anteil) and Map.has_key?(p, :stimmen) and is_integer(p.stimmen)
        end)
        |> Enum.each(fn party ->
          expected_anteil = ((party.stimmen / area.gueltige) * 100) |> Float.round(2)
          actual_anteil = party.anteil
          diff = (expected_anteil - actual_anteil) |> Float.round(2)

          IO.puts("    #{party.name}: stored=#{actual_anteil}% (expected=#{expected_anteil}%), diff=#{diff}%")
        end)
      end)
    end

    :ok
  end

  defp calculate_vote_check(areas) do
    {
      Enum.count(areas, fn area ->
        is_valid_area?(area) and check_vote_sum(area)
      end),
      Enum.count(areas, fn area -> is_valid_area?(area) end)
    }
    |> case do
      {passed, total} -> %{passed: passed, failed: total - passed, areas_with_data: total}
      _ -> %{passed: 0, failed: 0, areas_with_data: 0}
    end
  end

  defp calculate_percentage_check(areas) do
    {
      Enum.count(areas, fn area ->
        is_valid_area?(area) and check_percentage(area)
      end),
      length(areas)
    }
    |> case do
      {passed, _} -> %{passed: passed, failed: length(areas) - passed}
      _ -> %{passed: 0, failed: 0}
    end
  end

  defp is_valid_area?(area) do
    Map.has_key?(area, :gueltige) and area.gueltige not in [nil, 0]
  end

  defp check_vote_sum(area) do
    valid_parties =
      Enum.filter(area.parteien, fn party ->
        Map.has_key?(party, :stimmen) and is_integer(party.stimmen) and party.stimmen > 0
      end)

    if length(valid_parties) == 0 do
      false
    else
      sum_votes = Enum.sum(Enum.map(valid_parties, fn party -> party.stimmen end))
      # 1% tolerance
      abs(sum_votes - area.gueltige) <= abs(area.gueltige * 0.01)
    end
  end

  defp check_percentage(area) do
    Enum.filter(area.parteien, fn party ->
      Map.has_key?(party, :anteil) and is_float(party.anteil)
    end)
    |> Enum.all?(fn party ->
      expected_anteil = (party.stimmen / area.gueltige * 100) |> Float.round(1)
      abs(party.anteil - expected_anteil) <= @tolerance
    end)
  end

  defp calc_stats(area) do
    valid_parties =
      Enum.filter(area.parteien, fn party ->
        Map.has_key?(party, :stimmen) and is_integer(party.stimmen) and party.stimmen > 0
      end)

    sum_votes = Enum.sum(Enum.map(valid_parties, fn party -> party.stimmen end))
    {sum_votes, area.gueltige}
  end

  defp format_failures(failed_areas, failing_checks, type) do
    IO.puts("")
    IO.puts("#{String.upcase(to_string(type))} Failures (#{length(failed_areas)}):")

    failed_areas
    |> Enum.take(10)
    |> Enum.with_index(1)
    |> Enum.each(fn {_, index} ->
      check = Enum.at(failing_checks, index - 1, {:vote, ""})
      IO.puts("  #{index}. #{elem(check, 1)}")
    end)

    if length(failed_areas) > 10 do
      IO.puts("  ... and #{length(failed_areas) - 10} more")
    end
  end
end

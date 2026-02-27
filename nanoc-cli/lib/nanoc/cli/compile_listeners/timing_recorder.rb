# frozen_string_literal: true

module Nanoc::CLI::CompileListeners
  class TimingRecorder < Abstract
    class Table
      TOP = 1
      MIDDLE = 2
      BOTTOM = 3

      def initialize(header_row, body_rows, footer_row)
        @header_row = header_row
        @body_rows = body_rows
        @footer_row = footer_row

        @rows = [header_row] + body_rows + [footer_row]
      end

      def to_s
        columns = @rows.transpose
        column_lengths = columns.map { |c| c.map(&:size).max }

        [].tap do |lines|
          # header
          lines << separator(column_lengths, TOP)
          lines << row_to_s(@header_row, column_lengths)
          lines << separator(column_lengths, MIDDLE)

          # body
          rows = sort_rows(@body_rows)
          lines.concat(rows.map { |r| row_to_s(r, column_lengths) })

          # footer
          lines << separator(column_lengths, MIDDLE)
          lines << row_to_s(@footer_row, column_lengths)
          lines << separator(column_lengths, BOTTOM)
        end.join("\n")
      end

      private

      def sort_rows(rows)
        rows.sort_by { |r| r.first.downcase }
      end

      def row_to_s(row, column_lengths)
        values = row.zip(column_lengths).map { |text, length| text.rjust(length) }
        "│ #{values[0]} │ #{values.drop(1).join('   ')} │"
      end

      def separator(column_lengths, pos)
        (+'').tap do |s|
          s << case pos
               when TOP
                 '┌─'
               when MIDDLE
                 '├─'
               when BOTTOM
                 '└─'
               end

          s << column_lengths.take(1).map { |l| '─' * l }.join('───')

          s << case pos
               when TOP
                 '─┬─'
               when MIDDLE
                 '─┼─'
               when BOTTOM
                 '─┴─'
               end

          s << column_lengths.drop(1).map { |l| '─' * l }.join('───')

          s << case pos
               when TOP
                 '─┐'
               when MIDDLE
                 '─┤'
               when BOTTOM
                 '─┘'
               end
        end
      end
    end

    attr_reader :stages_summary
    attr_reader :outdatedness_rules_summary
    attr_reader :filters_summary

    # @see Listener#enable_for?
    def self.enable_for?(_command_runner, _config)
      Nanoc::CLI.verbosity >= 1
    end

    def initialize
      super

      @stages_summary = DDMetrics::Summary.new
      @outdatedness_rules_summary = DDMetrics::Summary.new
      @filters_summary = DDMetrics::Summary.new
      @load_stores_summary = DDMetrics::Summary.new
      @store_stores_summary = DDMetrics::Summary.new
    end

    # @see Listener#start
    def start
      Nanoc::Core::Instrumentor.enable

      on(:stage_ran) do |duration, klass|
        @stages_summary.observe(duration, name: klass.to_s.sub(/.*::/, ''))
      end

      on(:outdatedness_rule_ran) do |duration, klass|
        @outdatedness_rules_summary.observe(duration, name: klass.to_s.sub(/.*::/, ''))
      end

      stopwatches_stack = []

      on(:filtering_started) do |_rep, _filter_name|
        # Add new stopwatch and start it
        stopwatch = DDMetrics::Stopwatch.new
        stopwatches_stack << stopwatch
        stopwatch.start
      end

      on(:filtering_ended) do |_rep, filter_name|
        # Get topmost stopwatch and stop it
        stopwatch = stopwatches_stack.pop
        stopwatch.stop

        # Record duration
        @filters_summary.observe(stopwatch.duration, name: filter_name.to_s)
      end

      on(:store_loaded) do |duration, klass|
        @load_stores_summary.observe(duration, name: klass.to_s)
      end

      on(:store_stored) do |duration, klass|
        @store_stores_summary.observe(duration, name: klass.to_s)
      end
    end

    # @see Listener#stop
    def stop
      Nanoc::Core::Instrumentor.disable

      print_profiling_feedback
    end

    protected

    def table_for_summary(name, summary)
      header_row = [name.to_s, 'count', 'min', '.50', '.90', '.95', 'max', 'tot']

      grand_total = 0.0
      body_rows = summary.map do |label, stats|
        name = label.fetch(:name)

        count = stats.count
        min   = stats.min
        p50   = stats.quantile(0.50)
        p90   = stats.quantile(0.90)
        p95   = stats.quantile(0.95)
        tot   = stats.sum
        max   = stats.max

        grand_total += tot

        [name, count.to_s] + [min, p50, p90, p95, max, tot].map { |r| "#{format('%4.2f', r)}s" }
      end

      footer_row = ['tot', '', '', '', '', '', '', "#{format('%4.2f', grand_total)}s"]

      Table.new(header_row, body_rows, footer_row)
    end

    def table_for_summary_durations(name, summary)
      header_row = [name.to_s, 'tot']

      tot = 0.0
      body_rows = summary.map do |label, stats|
        name = label.fetch(:name)
        tot += stats.sum
        [name, "#{format('%4.2f', stats.sum)}s"]
      end

      footer_row = ['tot', "#{format('%4.2f', tot)}s"]

      Table.new(header_row, body_rows, footer_row)
    end

    def print_profiling_feedback
      print_table_for_summary(:filters, @filters_summary)
      print_table_for_summary_duration(:stages, @stages_summary) if Nanoc::CLI.verbosity >= 2
      print_table_for_summary(:outdatedness_rules, @outdatedness_rules_summary) if Nanoc::CLI.verbosity >= 2
      print_table_for_summary_duration(:load_stores, @load_stores_summary) if Nanoc::CLI.verbosity >= 2
      print_table_for_summary_duration(:store_stores, @store_stores_summary) if Nanoc::CLI.verbosity >= 2
    end

    def print_table_for_summary(name, summary)
      return unless summary.any?

      puts
      puts table_for_summary(name, summary)
    end

    def print_table_for_summary_duration(name, summary)
      return unless summary.any?

      puts
      puts table_for_summary_durations(name, summary)
    end
  end
end

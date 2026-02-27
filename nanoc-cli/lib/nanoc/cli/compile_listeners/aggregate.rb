# frozen_string_literal: true

module Nanoc::CLI::CompileListeners
  class Aggregate < Abstract
    def initialize(command_runner:, site:)
      super()

      @site = site
      @command_runner = command_runner

      @listener_classes = self.class.default_listener_classes
    end

    def start
      setup_listeners
    end

    def stop
      teardown_listeners
    end

    def self.default_listener_classes
      [
        Nanoc::CLI::CompileListeners::DiffGenerator,
        Nanoc::CLI::CompileListeners::DebugPrinter,
        Nanoc::CLI::CompileListeners::TimingRecorder,
        Nanoc::CLI::CompileListeners::FileActionPrinter,
      ]
    end

    protected

    def setup_listeners
      @listeners =
        @listener_classes
        .select { |klass| klass.enable_for?(@command_runner, @site) }
        .map(&:new)

      @listeners.each(&:start_safely)
    end

    def teardown_listeners
      return unless @listeners

      @listeners.reverse_each(&:stop_safely)
    end
  end
end

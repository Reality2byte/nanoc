# frozen_string_literal: true

require 'helper'

class Nanoc::CLI::Commands::HelpTest < Nanoc::TestCase
  def test_run
    Nanoc::CLI.run ['help']
    Nanoc::CLI.run ['help', 'co']
  end
end

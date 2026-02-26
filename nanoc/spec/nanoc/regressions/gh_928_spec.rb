# frozen_string_literal: true

describe 'GH-928', :site, :stdio do
  example do
    expect { Nanoc::CLI.run(['check', '--list']) }.to output(/^  css$/).to_stdout
  end
end

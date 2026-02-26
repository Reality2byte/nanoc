# frozen_string_literal: true

describe 'GH-1248', :site, :stdio do
  before do
    File.write('content/stuff.html', 'hi')

    File.write('Rules', <<~EOS)
      preprocess do
        @config[:output_dir] = 'ootpoot'
      end

      passthrough '/**/*'
    EOS

    Nanoc::CLI.run(['compile'])
  end

  example do
    expect { Nanoc::CLI.run(['compile', '--verbose']) }
      .not_to output(%r{identical .* ootpoot/stuff.html}).to_stdout
  end
end

# frozen_string_literal: true

describe 'GH-981', :site, :stdio do
  before do
    File.write('content/foo.md', 'I am foo!')

    File.write('Rules', <<EOS)
  compile '/foo.*' do
    filter :erb, stuff: self
    write '/foo.html'
  end
EOS
  end

  it 'creates at first' do
    expect { Nanoc::CLI.run(['compile', '--verbose']) }.to output(%r{create.*output/foo\.html$}).to_stdout
  end

  it 'skips the item on second try' do
    Nanoc::CLI.run(['compile'])
    expect { Nanoc::CLI.run(['compile', '--verbose']) }.not_to output(%r{output/foo\.html$}).to_stdout
  end
end

# frozen_string_literal: true

describe Nanoc::Core::CompilationPhases::Abstract do
  subject(:phase) do
    described_class.new(wrapped:)
  end

  let(:item) { Nanoc::Core::Item.new('foo', {}, '/stuff.md') }
  let(:rep) { Nanoc::Core::ItemRep.new(item, :default) }

  let(:wrapped) { nil }

  describe '#run' do
    subject do
      phase.run(rep, is_outdated: false) do
        # do nothing
      end
    end

    it 'raises' do
      expect { subject }.to raise_error(NotImplementedError)
    end
  end

  describe '#call' do
    subject { phase.call(rep, is_outdated: false) }

    let(:phase_class) do
      Class.new(described_class) do
        def self.to_s
          'AbstractSpec::MyTestingPhaseClass'
        end

        def run(_rep, is_outdated:) # rubocop:disable Lint/UnusedMethodArgument
          yield
        end
      end
    end

    let(:phase) { phase_class.new(wrapped:) }

    let(:wrapped_class) do
      Class.new(described_class) do
        def self.to_s
          'AbstractSpec::MyTestingWrappedPhaseClass'
        end

        def run(_rep, is_outdated:); end
      end
    end

    let(:wrapped) { wrapped_class.new(wrapped: nil) }

    it 'sends the proper notifications' do
      expect(Nanoc::Core::NotificationCenter).to receive(:post).with(
        :phase_started, 'MyTestingPhaseClass', rep
      ).ordered
      expect(Nanoc::Core::NotificationCenter).to receive(:post).with(
        :phase_yielded, 'MyTestingPhaseClass', rep
      ).ordered

      expect(Nanoc::Core::NotificationCenter).to receive(:post).with(
        :phase_started, 'MyTestingWrappedPhaseClass', rep
      ).ordered
      expect(Nanoc::Core::NotificationCenter).to receive(:post).with(
        :phase_ended, 'MyTestingWrappedPhaseClass', rep
      ).ordered

      expect(Nanoc::Core::NotificationCenter).to receive(:post).with(
        :phase_resumed, 'MyTestingPhaseClass', rep
      ).ordered
      expect(Nanoc::Core::NotificationCenter).to receive(:post).with(
        :phase_ended, 'MyTestingPhaseClass', rep
      ).ordered

      subject
    end
  end
end

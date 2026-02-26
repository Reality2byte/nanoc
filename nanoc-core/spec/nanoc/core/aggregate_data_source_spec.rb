# frozen_string_literal: true

describe Nanoc::Core::AggregateDataSource, :stdio do
  subject(:data_source) do
    described_class.new([data_source_a, data_source_b], {})
  end

  let(:klass_a) do
    Class.new(Nanoc::Core::DataSource) do
      def items
        [Nanoc::Core::Item.new('One', {}, '/one.md')]
      end

      def item_changes
        %i[one_foo one_bar]
      end

      def layouts
        [Nanoc::Core::Layout.new('One', {}, '/one.md')]
      end

      def layout_changes
        %i[one_foo one_bar]
      end
    end
  end

  let(:klass_b) do
    Class.new(Nanoc::Core::DataSource) do
      def items
        [Nanoc::Core::Item.new('Two', {}, '/two.md')]
      end

      def item_changes
        %i[two_foo two_bar]
      end

      def layouts
        [Nanoc::Core::Layout.new('Two', {}, '/two.md')]
      end

      def layout_changes
        %i[two_foo two_bar]
      end
    end
  end

  let(:data_source_a) do
    klass_a.new({}, nil, nil, {})
  end

  let(:data_source_b) do
    klass_b.new({}, nil, nil, {})
  end

  describe '#items' do
    subject { data_source.items }

    it 'contains all items' do
      expect(subject).to match_array(data_source_a.items + data_source_b.items)
    end
  end

  describe '#layouts' do
    subject { data_source.layouts }

    it 'contains all layouts' do
      expect(subject).to match_array(data_source_a.layouts + data_source_b.layouts)
    end
  end

  describe '#item_changes' do
    subject { data_source.item_changes }

    it 'yields changes from both' do
      expect(subject).to match_array(data_source_a.item_changes + data_source_b.item_changes)
    end
  end

  describe '#layout_changes' do
    subject { data_source.layout_changes }

    it 'yields changes from both' do
      expect(subject).to match_array(data_source_a.layout_changes + data_source_b.layout_changes)
    end
  end
end

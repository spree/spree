require 'spec_helper'

RSpec.describe Spree::NumberSequence do
  let(:store) { @default_store }

  describe '.next_value' do
    it 'starts at the requested value' do
      value = described_class.next_value(store: store, resource_type: 'order', start_at: 1001)

      expect(value).to eq(1001)
    end

    it 'advances by one per call' do
      3.times.map { described_class.next_value(store: store, resource_type: 'order', start_at: 1) }.
        then { |values| expect(values).to eq([1, 2, 3]) }
    end

    it 'counts each resource type separately' do
      described_class.next_value(store: store, resource_type: 'order', start_at: 1)
      described_class.next_value(store: store, resource_type: 'order', start_at: 1)

      expect(described_class.next_value(store: store, resource_type: 'return', start_at: 1)).to eq(1)
    end

    it 'counts each store separately' do
      other_store = create(:store)
      described_class.next_value(store: store, resource_type: 'order', start_at: 1)

      expect(described_class.next_value(store: other_store, resource_type: 'order', start_at: 1)).to eq(1)
    end

    it 'ignores a changed starting value once the counter exists' do
      described_class.next_value(store: store, resource_type: 'order', start_at: 1)

      expect(described_class.next_value(store: store, resource_type: 'order', start_at: 500)).to eq(2)
    end

    it 'never hands out the same value twice under concurrency' do
      values = Concurrent::Array.new

      threads = 4.times.map do
        Thread.new do
          ActiveRecord::Base.connection_pool.with_connection do
            values << described_class.next_value(store: store, resource_type: 'order', start_at: 1)
          end
        end
      end
      threads.each(&:join)

      expect(values.uniq.size).to eq(4)
    end
  end

  describe 'uniqueness' do
    it 'allows one row per store and resource type' do
      create(:number_sequence, store: store, resource_type: 'order')

      expect(build(:number_sequence, store: store, resource_type: 'order')).not_to be_valid
    end
  end
end

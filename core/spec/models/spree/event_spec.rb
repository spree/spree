# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Spree::Event do
  let(:store) { create(:store) }

  before do
    allow(Spree::Current).to receive(:store).and_return(store)
  end

  describe '#initialize' do
    it 'creates an event with name and payload' do
      event = described_class.new(
        name: 'order.complete',
        payload: { id: 1, number: 'R123' }
      )

      expect(event.name).to eq('order.complete')
      expect(event.payload).to eq({ 'id' => 1, 'number' => 'R123' })
    end

    it 'freezes the payload and metadata' do
      event = described_class.new(
        name: 'order.complete',
        payload: { id: 1 }
      )

      expect(event.payload).to be_frozen
      expect(event.metadata).to be_frozen
    end

    it 'sets created_at' do
      event = described_class.new(name: 'test', payload: {})
      expect(event.created_at).to be_within(1.second).of(Time.current)
    end

    it 'generates an id' do
      event = described_class.new(name: 'test', payload: {})
      expect(event.id).to be_present
      expect(event.id).to match(/\A[0-9a-f-]{36}\z/)
    end

    it 'includes spree_version in metadata' do
      event = described_class.new(name: 'test', payload: {})
      expect(event.metadata['spree_version']).to eq(Spree.version)
    end

    it 'accepts custom metadata' do
      event = described_class.new(
        name: 'test',
        payload: {},
        metadata: { custom_key: 'custom_value' }
      )

      expect(event.metadata['custom_key']).to eq('custom_value')
    end

    it 'deep stringifies payload keys' do
      event = described_class.new(
        name: 'test',
        payload: { nested: { deep_key: 'value' } }
      )

      expect(event.payload).to eq({ 'nested' => { 'deep_key' => 'value' } })
    end

    it 'sets store_id from Spree::Current.store' do
      event = described_class.new(name: 'test', payload: {})

      expect(event.store_id).to eq(store.id)
    end

    it 'accepts explicit store_id' do
      other_store = create(:store)
      event = described_class.new(name: 'test', store_id: other_store.id, payload: {})

      expect(event.store_id).to eq(other_store.id)
    end
  end

  describe 'validations' do
    it 'requires name' do
      event = described_class.new(store_id: store.id, payload: {})

      expect(event).not_to be_valid
      expect(event.errors[:name]).to include("can't be blank")
    end

    it 'requires store_id' do
      allow(Spree::Current).to receive(:store).and_return(nil)
      event = described_class.new(name: 'test', payload: {})

      expect(event).not_to be_valid
      expect(event.errors[:store_id]).to include("can't be blank")
    end

    it 'is valid with name and store_id' do
      event = described_class.new(name: 'test', store_id: store.id, payload: {})

      expect(event).to be_valid
    end
  end

  describe '#store' do
    it 'returns the store for the store_id' do
      event = described_class.new(name: 'order.complete', store_id: store.id)

      expect(event.store).to eq(store)
    end

    it 'returns nil when store_id is blank' do
      allow(Spree::Current).to receive(:store).and_return(nil)
      event = described_class.new(name: 'order.complete', store_id: nil)

      expect(event.store).to be_nil
    end

    it 'memoizes the store lookup' do
      event = described_class.new(name: 'order.complete', store_id: store.id)

      expect(Spree::Store).to receive(:find_by).once.and_return(store)

      2.times { event.store }
    end
  end

  describe '#resource_type' do
    it 'extracts the resource type from the event name' do
      event = described_class.new(name: 'order.complete', payload: {})
      expect(event.resource_type).to eq('order')
    end

    it 'handles nested event names' do
      event = described_class.new(name: 'stock_item.low_stock', payload: {})
      expect(event.resource_type).to eq('stock_item')
    end
  end

  describe '#action' do
    it 'extracts the action from the event name' do
      event = described_class.new(name: 'order.complete', payload: {})
      expect(event.action).to eq('complete')
    end

    it 'handles multi-part actions' do
      event = described_class.new(name: 'stock_item.low_stock', payload: {})
      expect(event.action).to eq('low_stock')
    end
  end

  describe '#matches?' do
    let(:event) { described_class.new(name: 'order.complete', payload: {}) }

    it 'matches exact event names' do
      expect(event.matches?('order.complete')).to be true
      expect(event.matches?('order.cancel')).to be false
    end

    it 'matches wildcard patterns' do
      expect(event.matches?('order.*')).to be true
      expect(event.matches?('product.*')).to be false
    end

    it 'matches global wildcard' do
      expect(event.matches?('*')).to be true
    end
  end

  describe '.matches?' do
    it 'matches exact names' do
      expect(described_class.matches?('order.complete', 'order.complete')).to be true
      expect(described_class.matches?('order.complete', 'order.cancel')).to be false
    end

    it 'matches wildcard patterns' do
      expect(described_class.matches?('order.complete', 'order.*')).to be true
      expect(described_class.matches?('order.cancel', 'order.*')).to be true
      expect(described_class.matches?('product.create', 'order.*')).to be false
    end

    it 'matches global wildcard' do
      expect(described_class.matches?('order.complete', '*')).to be true
      expect(described_class.matches?('anything.here', '*')).to be true
    end

    it 'handles complex patterns' do
      expect(described_class.matches?('order.line_item.update', 'order.line_item.*')).to be true
      expect(described_class.matches?('order.line_item.update', 'order.*')).to be true
    end
  end

  describe '#attributes' do
    it 'returns a hash representation with string keys' do
      event = described_class.new(
        name: 'order.complete',
        payload: { id: 1 },
        metadata: { user_id: 5 }
      )

      hash = event.attributes

      expect(hash['name']).to eq('order.complete')
      expect(hash['store_id']).to eq(store.id)
      expect(hash['payload']).to eq({ 'id' => 1 })
      expect(hash['metadata']['user_id']).to eq(5)
      expect(hash['created_at']).to eq(event.created_at)
    end
  end

  describe '#inspect' do
    it 'returns a readable string representation' do
      event = described_class.new(name: 'order.complete', payload: {})
      expect(event.inspect).to match(/Spree::Event id="[0-9a-f-]{36}" name="order.complete" store_id=#{store.id} created_at=/)
    end
  end
end

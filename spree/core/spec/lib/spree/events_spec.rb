# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Spree::Events, events: true do
  before do
    described_class.reset!
  end

  after do
    described_class.reset!
  end

  describe '.publish' do
    it 'publishes an event' do
      event = described_class.publish('order.completed', { id: 1 })

      expect(event).to be_a(Spree::Event)
      expect(event.name).to eq('order.completed')
      expect(event.payload).to eq({ 'id' => 1 })
    end

    it 'notifies subscribers synchronously when async: false' do
      received_events = []

      described_class.subscribe('order.completed', async: false) do |event|
        received_events << event
      end

      described_class.activate!
      described_class.publish('order.completed', { id: 1 })

      expect(received_events.size).to eq(1)
    end
  end

  describe '.subscribe' do
    it 'subscribes with a block' do
      called = false

      described_class.subscribe('order.completed', async: false) do |_event|
        called = true
      end

      described_class.activate!
      described_class.publish('order.completed', {})

      expect(called).to be true
    end

    it 'subscribes with a class' do
      received = []
      handler_class = Class.new do
        define_singleton_method(:call) do |event|
          received << event
        end
      end

      described_class.subscribe('order.completed', handler_class, async: false)
      described_class.activate!
      described_class.publish('order.completed', {})

      expect(received.size).to eq(1)
    end

    it 'supports pattern matching with wildcards' do
      received_events = []

      described_class.subscribe('order.*', async: false) do |event|
        received_events << event
      end

      described_class.activate!
      described_class.publish('order.completed', {})
      described_class.publish('order.canceled', {})
      described_class.publish('product.created', {})

      expect(received_events.size).to eq(2)
      expect(received_events.map(&:name)).to contain_exactly('order.completed', 'order.canceled')
    end

    it 'supports global wildcard' do
      received_events = []

      described_class.subscribe('*', async: false) do |event|
        received_events << event
      end

      described_class.activate!
      described_class.publish('order.completed', {})
      described_class.publish('product.created', {})

      expect(received_events.size).to eq(2)
    end

    it 'raises error when no subscriber provided' do
      expect { described_class.subscribe('order.completed') }.to raise_error(ArgumentError)
    end
  end

  describe '.unsubscribe' do
    it 'removes a subscriber' do
      received_events = []
      handler = ->(event) { received_events << event }

      described_class.subscribe('order.completed', handler, async: false)
      described_class.unsubscribe('order.completed', handler)
      described_class.activate!
      described_class.publish('order.completed', {})

      expect(received_events).to be_empty
    end
  end

  describe '.patterns' do
    it 'returns all registered patterns' do
      described_class.subscribe('order.completed', async: false) { }
      described_class.subscribe('order.*', async: false) { }

      expect(described_class.patterns).to contain_exactly('order.completed', 'order.*')
    end
  end

  describe '.subscriptions' do
    it 'returns all subscriptions' do
      described_class.subscribe('order.completed', async: false) { }
      described_class.subscribe('order.canceled', async: false) { }

      expect(described_class.subscriptions.size).to eq(2)
    end
  end

  describe '.disable' do
    it 'disables events within the block' do
      received = false

      described_class.subscribe('order.completed', async: false) do
        received = true
      end

      described_class.activate!

      described_class.disable do
        described_class.publish('order.completed', {})
      end

      expect(received).to be false
    end

    it 'restores enabled state after the block' do
      described_class.disable do
        expect(described_class.enabled?).to be false
      end

      expect(described_class.enabled?).to be true
    end

    it 'handles nested disable blocks' do
      described_class.disable do
        described_class.disable do
          expect(described_class.enabled?).to be false
        end
        expect(described_class.enabled?).to be false
      end

      expect(described_class.enabled?).to be true
    end
  end

  describe '.enabled?' do
    it 'returns true by default' do
      expect(described_class.enabled?).to be true
    end

    it 'returns false when disabled' do
      described_class.disable do
        expect(described_class.enabled?).to be false
      end
    end
  end

  describe '.reset!' do
    it 'clears all subscriptions' do
      described_class.subscribe('order.completed', async: false) { }

      described_class.reset!

      expect(described_class.subscriptions).to be_empty
    end
  end

  describe 'multiple subscribers' do
    it 'notifies all matching subscribers' do
      received1 = []
      received2 = []

      described_class.subscribe('order.completed', async: false) { |e| received1 << e }
      described_class.subscribe('order.completed', async: false) { |e| received2 << e }

      described_class.activate!
      described_class.publish('order.completed', {})

      expect(received1.size).to eq(1)
      expect(received2.size).to eq(1)
    end

    it 'handles mixed pattern and exact subscribers' do
      exact_received = []
      pattern_received = []

      described_class.subscribe('order.completed', async: false) { |e| exact_received << e }
      described_class.subscribe('order.*', async: false) { |e| pattern_received << e }

      described_class.activate!
      described_class.publish('order.completed', {})
      described_class.publish('order.canceled', {})

      expect(exact_received.size).to eq(1)
      expect(pattern_received.size).to eq(2)
    end
  end

  describe '.resolve_subscriber' do
    it 'returns the subscriber directly in production' do
      allow(Rails.env).to receive(:development?).and_return(false)
      allow(Rails.env).to receive(:test?).and_return(false)

      subscriber = Class.new(Spree::Subscriber)
      result = described_class.resolve_subscriber(subscriber)

      expect(result).to eq(subscriber)
    end

    it 'resolves subscriber by name in development' do
      allow(Rails.env).to receive(:development?).and_return(true)

      result = described_class.resolve_subscriber(Spree::Subscriber)

      expect(result).to eq(Spree::Subscriber)
    end

    it 'handles string class names' do
      allow(Rails.env).to receive(:development?).and_return(true)

      result = described_class.resolve_subscriber('Spree::Subscriber')

      expect(result).to eq(Spree::Subscriber)
    end

    it 'returns nil for invalid class names' do
      allow(Rails.env).to receive(:development?).and_return(true)

      result = described_class.resolve_subscriber('NonExistent::Class')

      expect(result).to be_nil
    end

    it 'returns nil for anonymous classes' do
      allow(Rails.env).to receive(:development?).and_return(true)

      anonymous_class = Class.new
      result = described_class.resolve_subscriber(anonymous_class)

      expect(result).to be_nil
    end
  end

  describe '.register_subscribers!' do
    let(:test_subscriber) do
      Class.new(Spree::Subscriber) do
        subscribes_to 'test.event'

        def handle(event)
          # no-op for test
        end
      end
    end

    before do
      stub_const('TestEventSubscriber', test_subscriber)
      allow(Spree).to receive(:subscribers).and_return([TestEventSubscriber])
    end

    it 'registers subscribers from Spree.subscribers' do
      described_class.register_subscribers!

      expect(described_class.patterns).to include('test.event')
    end

    it 'resolves subscriber classes fresh (for code reload support)' do
      # Simulate what happens during code reload:
      # The class in Spree.subscribers is stale but has the same name
      old_class = test_subscriber
      allow(Spree).to receive(:subscribers).and_return([old_class])

      described_class.register_subscribers!

      # The constant TestEventSubscriber should be resolved, not the old_class directly
      expect(described_class.subscriptions.first.subscriber).to eq(TestEventSubscriber)
    end
  end
end

# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Spree::Subscriber do
  before do
    Spree::Events.reset!
  end

  after do
    Spree::Events.reset!
  end

  describe '.subscribes_to' do
    it 'registers subscription patterns' do
      subscriber_class = Class.new(described_class) do
        subscribes_to 'order.complete'
      end

      expect(subscriber_class.subscription_patterns).to eq(['order.complete'])
    end

    it 'accepts multiple patterns' do
      subscriber_class = Class.new(described_class) do
        subscribes_to 'order.complete', 'order.cancel'
      end

      expect(subscriber_class.subscription_patterns).to contain_exactly('order.complete', 'order.cancel')
    end

    it 'stores subscription options' do
      subscriber_class = Class.new(described_class) do
        subscribes_to 'order.complete', async: false
      end

      expect(subscriber_class.subscription_options).to eq({ async: false })
    end

    it 'accumulates patterns from multiple calls' do
      subscriber_class = Class.new(described_class) do
        subscribes_to 'order.complete'
        subscribes_to 'order.cancel'
      end

      expect(subscriber_class.subscription_patterns).to contain_exactly('order.complete', 'order.cancel')
    end
  end

  describe '.on' do
    it 'maps events to methods' do
      subscriber_class = Class.new(described_class) do
        subscribes_to 'payment.complete', 'payment.void'
        on 'payment.complete', :handle_complete
        on 'payment.void', :handle_void
      end

      expect(subscriber_class.event_handlers).to eq({
        'payment.complete' => :handle_complete,
        'payment.void' => :handle_void
      })
    end
  end

  describe '.register!' do
    it 'registers the subscriber with the event system' do
      subscriber_class = Class.new(described_class) do
        subscribes_to 'order.complete'
      end

      subscriber_class.register!

      expect(Spree::Events.patterns).to include('order.complete')
    end

    it 'does nothing when no patterns defined' do
      subscriber_class = Class.new(described_class)

      expect { subscriber_class.register! }.not_to change { Spree::Events.patterns.size }
    end
  end

  describe '.unregister!' do
    it 'removes the subscriber from the event system' do
      subscriber_class = Class.new(described_class) do
        subscribes_to 'order.complete'
      end

      subscriber_class.register!
      subscriber_class.unregister!

      expect(Spree::Events.subscriptions).to be_empty
    end
  end

  describe '#call' do
    context 'without event handlers' do
      it 'calls the handle method' do
        handled_events = []

        subscriber_class = Class.new(described_class) do
          define_method(:handle) do |event|
            handled_events << event
          end
        end

        event = Spree::Event.new(name: 'order.complete', payload: {})
        subscriber_class.new.call(event)

        expect(handled_events).to eq([event])
      end
    end

    context 'with event handlers' do
      it 'routes to the correct handler' do
        called_handlers = []

        subscriber_class = Class.new(described_class) do
          subscribes_to 'payment.complete', 'payment.void'
          on 'payment.complete', :handle_complete
          on 'payment.void', :handle_void

          define_method(:handle_complete) do |event|
            called_handlers << [:complete, event]
          end

          define_method(:handle_void) do |event|
            called_handlers << [:void, event]
          end
        end

        complete_event = Spree::Event.new(name: 'payment.complete', payload: {})
        void_event = Spree::Event.new(name: 'payment.void', payload: {})

        subscriber_class.new.call(complete_event)
        subscriber_class.new.call(void_event)

        expect(called_handlers).to eq([
          [:complete, complete_event],
          [:void, void_event]
        ])
      end

      it 'falls back to handle when no matching handler' do
        handled_events = []

        subscriber_class = Class.new(described_class) do
          subscribes_to 'payment.*'
          on 'payment.complete', :handle_complete

          define_method(:handle_complete) do |_event|
            # Should not be called for refund events
          end

          define_method(:handle) do |event|
            handled_events << event
          end
        end

        event = Spree::Event.new(name: 'payment.refund', payload: {})
        subscriber_class.new.call(event)

        expect(handled_events).to eq([event])
      end
    end
  end

  describe '.call' do
    it 'creates an instance and calls it' do
      called = false

      subscriber_class = Class.new(described_class) do
        define_method(:handle) do |_event|
          called = true
        end
      end

      event = Spree::Event.new(name: 'test', payload: {})
      subscriber_class.call(event)

      expect(called).to be true
    end
  end

  describe 'integration' do
    it 'receives events when registered' do
      received_events = []

      subscriber_class = Class.new(described_class) do
        subscribes_to 'test.event', async: false

        define_method(:handle) do |event|
          received_events << event
        end
      end

      subscriber_class.register!
      Spree::Events.activate!

      Spree::Events.publish('test.event', { key: 'value' })

      expect(received_events.size).to eq(1)
      expect(received_events.first.name).to eq('test.event')
      expect(received_events.first.payload).to eq({ 'key' => 'value' })
    end
  end
end

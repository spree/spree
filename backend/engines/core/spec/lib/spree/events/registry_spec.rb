# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Spree::Events::Registry do
  let(:registry) { described_class.new }
  let(:subscriber_class) { Class.new }
  let(:another_subscriber) { Class.new }

  describe '#register' do
    it 'registers a subscriber for a pattern' do
      registry.register('order.complete', subscriber_class)

      expect(registry.size).to eq(1)
      expect(registry.registered?('order.complete')).to be true
    end

    it 'allows multiple subscribers for the same pattern' do
      registry.register('order.complete', subscriber_class)
      registry.register('order.complete', another_subscriber)

      expect(registry.size).to eq(2)
    end

    it 'stores subscription options' do
      registry.register('order.complete', subscriber_class, async: false)

      subscription = registry.subscriptions_for('order.complete').first
      expect(subscription.options[:async]).to be false
    end

    it 'returns the subscription' do
      subscription = registry.register('order.complete', subscriber_class)

      expect(subscription).to be_a(Spree::Events::Registry::Subscription)
      expect(subscription.pattern).to eq('order.complete')
      expect(subscription.subscriber).to eq(subscriber_class)
    end
  end

  describe '#unregister' do
    before do
      registry.register('order.complete', subscriber_class)
      registry.register('order.complete', another_subscriber)
    end

    it 'removes a specific subscriber' do
      result = registry.unregister('order.complete', subscriber_class)

      expect(result).to be true
      expect(registry.size).to eq(1)
      expect(registry.subscriptions_for('order.complete').map(&:subscriber)).not_to include(subscriber_class)
    end

    it 'returns false when subscriber not found' do
      result = registry.unregister('order.cancel', subscriber_class)

      expect(result).to be false
    end

    it 'keeps other subscribers intact' do
      registry.unregister('order.complete', subscriber_class)

      expect(registry.subscriptions_for('order.complete').map(&:subscriber)).to include(another_subscriber)
    end
  end

  describe '#subscriptions_for' do
    before do
      registry.register('order.complete', subscriber_class)
      registry.register('order.*', another_subscriber)
    end

    it 'returns subscriptions for exact match' do
      subscriptions = registry.subscriptions_for('order.complete')

      expect(subscriptions.size).to eq(2)
    end

    it 'returns subscriptions matching wildcard patterns' do
      subscriptions = registry.subscriptions_for('order.cancel')

      expect(subscriptions.size).to eq(1)
      expect(subscriptions.first.subscriber).to eq(another_subscriber)
    end

    it 'returns empty array when no matches' do
      subscriptions = registry.subscriptions_for('product.create')

      expect(subscriptions).to be_empty
    end

    context 'with global wildcard' do
      before { registry.register('*', Class.new) }

      it 'matches all events' do
        expect(registry.subscriptions_for('order.complete').size).to eq(3)
        expect(registry.subscriptions_for('product.create').size).to eq(1)
      end
    end
  end

  describe '#all_subscriptions' do
    it 'returns all registered subscriptions' do
      registry.register('order.complete', subscriber_class)
      registry.register('order.*', another_subscriber)

      subscriptions = registry.all_subscriptions

      expect(subscriptions.size).to eq(2)
    end

    it 'returns a copy of the subscriptions' do
      registry.register('order.complete', subscriber_class)

      subscriptions = registry.all_subscriptions
      subscriptions.clear

      expect(registry.size).to eq(1)
    end
  end

  describe '#patterns' do
    it 'returns unique patterns' do
      registry.register('order.complete', subscriber_class)
      registry.register('order.complete', another_subscriber)
      registry.register('order.*', subscriber_class)

      expect(registry.patterns).to contain_exactly('order.complete', 'order.*')
    end
  end

  describe '#clear!' do
    it 'removes all subscriptions' do
      registry.register('order.complete', subscriber_class)
      registry.register('order.*', another_subscriber)

      registry.clear!

      expect(registry.size).to eq(0)
    end
  end

  describe '#registered?' do
    it 'returns true for registered patterns' do
      registry.register('order.complete', subscriber_class)

      expect(registry.registered?('order.complete')).to be true
    end

    it 'returns false for unregistered patterns' do
      expect(registry.registered?('order.complete')).to be false
    end
  end

  describe 'thread safety' do
    it 'handles concurrent registrations' do
      threads = 10.times.map do |i|
        Thread.new do
          registry.register("event.#{i}", subscriber_class)
        end
      end

      threads.each(&:join)

      expect(registry.size).to eq(10)
    end
  end
end

# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Spree::EventLogSubscriber do
  describe '.attach_to_notifications' do
    before do
      # Detach first since it may be attached by the engine's after_initialize
      described_class.detach_from_notifications
    end

    after do
      described_class.detach_from_notifications
    end

    it 'subscribes to Spree events' do
      expect(described_class.attached?).to be false
      described_class.attach_to_notifications
      expect(described_class.attached?).to be true
    end

    it 'can be called multiple times safely (for code reload support)' do
      described_class.attach_to_notifications
      expect(described_class.attached?).to be true

      # Calling again should still work (detaches and re-attaches)
      described_class.attach_to_notifications
      expect(described_class.attached?).to be true
    end
  end

  describe '.detach_from_notifications' do
    it 'unsubscribes from notifications' do
      described_class.attach_to_notifications
      expect(described_class.attached?).to be true
      described_class.detach_from_notifications
      expect(described_class.attached?).to be false
    end
  end

  describe 'logging events' do
    before do
      described_class.attach_to_notifications
    end

    after do
      described_class.detach_from_notifications
    end

    it 'logs events to Rails logger' do
      event = Spree::Event.new(
        name: 'order.complete',
        payload: { 'id' => 1, 'number' => 'R123' },
        metadata: {}
      )

      expect(Rails.logger).to receive(:info).with(/\[Spree Event\].*order\.complete/)

      ActiveSupport::Notifications.instrument('order.complete.spree', event: event) {}
    end

    describe 'filtering sensitive parameters' do
      it 'filters password from payload' do
        event = Spree::Event.new(
          name: 'user.create',
          payload: { 'id' => 1, 'email' => 'test@example.com', 'password' => 'secret123' },
          metadata: {}
        )

        expect(Rails.logger).to receive(:info) do |message|
          expect(message).to include('[Spree Event]')
          expect(message).to include('user.create')
          expect(message).to include('[FILTERED]')
          expect(message).not_to include('secret123')
        end

        ActiveSupport::Notifications.instrument('user.create.spree', event: event) {}
      end

      it 'filters credit card number from payload' do
        event = Spree::Event.new(
          name: 'payment.create',
          payload: { 'id' => 1, 'number' => '4111111111111111' },
          metadata: {}
        )

        expect(Rails.logger).to receive(:info) do |message|
          expect(message).to include('[Spree Event]')
          expect(message).to include('payment.create')
          expect(message).to include('[FILTERED]')
          expect(message).not_to include('4111111111111111')
        end

        ActiveSupport::Notifications.instrument('payment.create.spree', event: event) {}
      end

      it 'filters verification_value from payload' do
        event = Spree::Event.new(
          name: 'payment.create',
          payload: { 'id' => 1, 'verification_value' => '123' },
          metadata: {}
        )

        expect(Rails.logger).to receive(:info) do |message|
          expect(message).not_to include('"123"')
        end

        ActiveSupport::Notifications.instrument('payment.create.spree', event: event) {}
      end

      it 'does not filter non-sensitive data' do
        event = Spree::Event.new(
          name: 'order.complete',
          payload: { 'id' => 42, 'total' => '99.99', 'state' => 'complete' },
          metadata: {}
        )

        expect(Rails.logger).to receive(:info) do |message|
          expect(message).to include('42')
          expect(message).to include('99.99')
          expect(message).to include('complete')
        end

        ActiveSupport::Notifications.instrument('order.complete.spree', event: event) {}
      end
    end
  end
end

# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Spree::OrderPlacedSubscriber do
  let(:store) { @default_store }
  let(:subscriber) { described_class.new }
  let(:customer) { create(:user, email: 'buyer@example.com') }
  let(:order) { create(:order, store: store, customer: customer, email: customer.email) }

  def mock_event(record)
    double('Event', payload: { 'id' => record.prefixed_id })
  end

  before { allow_any_instance_of(Spree::Order).to receive(:consider_risk) }

  describe '#handle newsletter subscription on order.placed' do
    context 'when the order opted into marketing' do
      before { order.update!(accept_marketing: true) }

      it 'subscribes the order customer via customer:' do
        expect(Spree::NewsletterSubscriber).to receive(:subscribe).
          with(email: order.email, customer: customer, store: store)

        subscriber.handle(mock_event(order))
      end

      it 'creates the subscriber without raising' do
        expect { subscriber.handle(mock_event(order)) }.
          to change { Spree::NewsletterSubscriber.for_store(store).count }.by(1)
      end
    end

    context 'when the order did not opt into marketing' do
      before { order.update!(accept_marketing: false) }

      it 'does not subscribe' do
        expect(Spree::NewsletterSubscriber).not_to receive(:subscribe)

        subscriber.handle(mock_event(order))
      end
    end
  end
end

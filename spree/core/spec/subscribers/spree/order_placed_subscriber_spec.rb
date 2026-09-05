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

  describe '#handle account creation on order.placed' do
    let(:guest_order) do
      create(:completed_order_with_totals, store: store, customer: nil, email: 'guest@example.com')
    end

    context 'when the order asked for an account' do
      before { guest_order.update!(signup_for_an_account: true) }

      it 'creates the account through the registration workflow' do
        expect { subscriber.handle(mock_event(guest_order)) }.
          to change { Spree.customer_class.count }.by(1)

        expect(guest_order.reload.customer.email).to eq('guest@example.com')
      end
    end

    context 'when the order did not ask for an account' do
      it 'creates nothing' do
        expect { subscriber.handle(mock_event(guest_order)) }.
          not_to change { Spree.customer_class.count }
      end
    end
  end
  describe 'consent recorded at checkout' do
    it 'records the marketing opt-in against the order' do
      order.update!(accept_marketing: true, customer: nil)
      allow(Spree::NewsletterSubscriber).to receive(:subscribe)

      subscriber.handle(mock_event(order))

      record = Spree::ConsentRecord.find_by(owner: order, purpose: Spree::ConsentRecord::EMAIL_MARKETING)

      expect(record).to be_present
      expect(record.source).to eq(Spree::ConsentRecord::CHECKOUT)
    end

    # An unticked box is the absence of consent, not a decision to refuse.
    it 'records nothing when the buyer did not opt in' do
      order.update!(accept_marketing: false)

      subscriber.handle(mock_event(order))

      expect(Spree::ConsentRecord.where(owner: order)).to be_empty
    end

    it 'writes one row when the buyer also created an account' do
      order.update!(accept_marketing: true, customer: nil, signup_for_an_account: true)
      allow(Spree::NewsletterSubscriber).to receive(:subscribe)

      subscriber.handle(mock_event(order))

      marketing = Spree::ConsentRecord.where(purpose: Spree::ConsentRecord::EMAIL_MARKETING)

      # One tick of one box is one agreement, however many records the
      # completion happens to create.
      expect(marketing.count).to eq(1)
    end
  end

end

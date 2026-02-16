# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Spree::PaymentSession, type: :model do
  let(:store) { @default_store }
  let(:order) { create(:order, store: store, total: 50) }
  let(:payment_method) { create(:bogus_payment_method, stores: [store]) }
  let(:payment_session) { create(:bogus_payment_session, order: order, payment_method: payment_method, amount: 50) }

  describe 'validations' do
    it { expect(payment_session).to be_valid }

    it 'requires order' do
      payment_session.order = nil
      expect(payment_session).not_to be_valid
    end

    it 'requires payment_method' do
      payment_session.payment_method = nil
      expect(payment_session).not_to be_valid
    end

    it 'requires external_id' do
      payment_session.external_id = nil
      expect(payment_session).not_to be_valid
    end

    it 'requires currency' do
      payment_session.currency = nil
      expect(payment_session).not_to be_valid
    end

    it 'requires amount greater than 0' do
      payment_session.amount = 0
      expect(payment_session).not_to be_valid
    end

    it 'enforces external_id uniqueness per order and payment method' do
      duplicate = build(:bogus_payment_session,
                        order: payment_session.order,
                        payment_method: payment_session.payment_method,
                        external_id: payment_session.external_id)
      expect(duplicate).not_to be_valid
    end
  end

  describe 'defaults from order' do
    it 'sets currency from order' do
      session = build(:bogus_payment_session, order: order, payment_method: payment_method,
                      external_id: 'test_123', currency: nil)
      session.valid?
      expect(session.currency).to eq(order.currency)
    end

    it 'sets customer from order user' do
      user = create(:user)
      order.update!(user: user)
      session = create(:bogus_payment_session, order: order, payment_method: payment_method,
                       external_id: 'test_456')
      expect(session.customer).to eq(user)
    end
  end

  describe 'state machine' do
    describe '#process' do
      it 'transitions from pending to processing' do
        expect(payment_session.process).to be true
        expect(payment_session.status).to eq('processing')
      end
    end

    describe '#complete' do
      it 'transitions from pending to completed' do
        expect(payment_session.complete).to be true
        expect(payment_session.status).to eq('completed')
      end

      it 'transitions from processing to completed' do
        payment_session.process
        expect(payment_session.complete).to be true
        expect(payment_session.status).to eq('completed')
      end
    end

    describe '#fail' do
      it 'transitions from pending to failed' do
        expect(payment_session.fail).to be true
        expect(payment_session.status).to eq('failed')
      end

      it 'transitions from processing to failed' do
        payment_session.process
        expect(payment_session.fail).to be true
        expect(payment_session.status).to eq('failed')
      end
    end

    describe '#cancel' do
      it 'transitions from pending to canceled' do
        expect(payment_session.cancel).to be true
        expect(payment_session.status).to eq('canceled')
      end
    end

    describe '#expire' do
      it 'transitions from pending to expired' do
        expect(payment_session.expire).to be true
        expect(payment_session.status).to eq('expired')
      end
    end

    it 'does not allow transitioning from completed' do
      payment_session.complete
      expect(payment_session.cancel).to be false
      expect(payment_session.status).to eq('completed')
    end

    it 'does not allow transitioning from failed' do
      payment_session.fail
      expect(payment_session.complete).to be false
      expect(payment_session.status).to eq('failed')
    end
  end

  describe 'scopes' do
    describe '.active' do
      it 'includes pending sessions' do
        expect(described_class.active).to include(payment_session)
      end

      it 'includes processing sessions' do
        payment_session.process
        expect(described_class.active).to include(payment_session)
      end

      it 'excludes completed sessions' do
        payment_session.complete
        expect(described_class.active).not_to include(payment_session)
      end

      it 'excludes expired sessions' do
        expired = create(:bogus_payment_session, :expired, order: order,
                         payment_method: payment_method)
        expect(described_class.active).not_to include(expired)
      end
    end

    describe '.not_expired' do
      it 'includes sessions without expires_at' do
        expect(described_class.not_expired).to include(payment_session)
      end

      it 'includes sessions with future expires_at' do
        payment_session.update!(expires_at: 1.hour.from_now)
        expect(described_class.not_expired).to include(payment_session)
      end

      it 'excludes sessions with past expires_at' do
        expired = create(:bogus_payment_session, :expired, order: order,
                         payment_method: payment_method)
        expect(described_class.not_expired).not_to include(expired)
      end
    end
  end

  describe '#amount_in_cents' do
    it 'returns amount in cents' do
      payment_session.update!(amount: 99.99)
      expect(payment_session.amount_in_cents).to eq(9999)
    end
  end

  describe '#expired?' do
    it 'returns false when expires_at is nil' do
      expect(payment_session.expired?).to be false
    end

    it 'returns false when expires_at is in the future' do
      payment_session.update!(expires_at: 1.hour.from_now)
      expect(payment_session.expired?).to be false
    end

    it 'returns true when expires_at is in the past' do
      payment_session.update!(expires_at: 1.hour.ago)
      expect(payment_session.expired?).to be true
    end
  end

  describe '#prefixed_id' do
    it 'starts with ps_' do
      expect(payment_session.prefixed_id).to start_with('ps_')
    end
  end

  describe 'soft delete' do
    it 'soft deletes with acts_as_paranoid' do
      payment_session.destroy
      expect(described_class.with_deleted.find(payment_session.id)).to be_present
      expect(described_class.find_by(id: payment_session.id)).to be_nil
    end
  end

  describe 'events' do
    before do
      allow(Spree::Events).to receive(:enabled?).and_return(true)
      allow(Spree::Events).to receive(:publish)
    end

    describe 'lifecycle events' do
      it 'publishes payment_session.created on create' do
        create(:bogus_payment_session, order: order, payment_method: payment_method)
        expect(Spree::Events).to have_received(:publish).with('payment_session.created', anything, anything)
      end

      it 'publishes payment_session.updated on update' do
        payment_session.update!(amount: 75)
        expect(Spree::Events).to have_received(:publish).with('payment_session.updated', anything, anything)
      end
    end

    describe 'state transition events' do
      it 'publishes payment_session.processing on process' do
        payment_session.process
        expect(Spree::Events).to have_received(:publish).with('payment_session.processing', anything, anything)
      end

      it 'publishes payment_session.completed on complete' do
        payment_session.complete
        expect(Spree::Events).to have_received(:publish).with('payment_session.completed', anything, anything)
      end

      it 'publishes payment_session.failed on fail' do
        payment_session.fail
        expect(Spree::Events).to have_received(:publish).with('payment_session.failed', anything, anything)
      end

      it 'publishes payment_session.canceled on cancel' do
        payment_session.cancel
        expect(Spree::Events).to have_received(:publish).with('payment_session.canceled', anything, anything)
      end

      it 'publishes payment_session.expired on expire' do
        payment_session.expire
        expect(Spree::Events).to have_received(:publish).with('payment_session.expired', anything, anything)
      end

      it 'does not publish events when events are disabled' do
        allow(Spree::Events).to receive(:enabled?).and_return(false)

        payment_session.complete

        expect(Spree::Events).not_to have_received(:publish).with('payment_session.completed', anything, anything)
      end
    end
  end
end

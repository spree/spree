# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Spree::PaymentSetupSession, type: :model do
  let(:store) { @default_store }
  let(:user) { create(:user) }
  let(:payment_method) { create(:bogus_payment_method, stores: [store]) }
  let(:payment_setup_session) { create(:payment_setup_session, customer: user, payment_method: payment_method) }

  describe 'validations' do
    it { expect(payment_setup_session).to be_valid }

    it 'requires payment_method' do
      payment_setup_session.payment_method = nil
      expect(payment_setup_session).not_to be_valid
    end

    it 'enforces unique external_id per payment_method' do
      payment_setup_session.update!(external_id: 'seti_123')
      duplicate = build(:payment_setup_session, payment_method: payment_method, external_id: 'seti_123')
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:external_id]).to be_present
    end

    it 'allows same external_id on different payment methods' do
      payment_setup_session.update!(external_id: 'seti_123')
      other_pm = create(:bogus_payment_method, stores: [store])
      other = build(:payment_setup_session, payment_method: other_pm, external_id: 'seti_123')
      expect(other).to be_valid
    end

    it 'allows nil external_id' do
      session1 = create(:payment_setup_session, customer: user, payment_method: payment_method, external_id: nil)
      session2 = build(:payment_setup_session, customer: user, payment_method: payment_method, external_id: nil)
      expect(session2).to be_valid
    end
  end

  describe 'associations' do
    it 'belongs to customer' do
      expect(payment_setup_session.customer).to eq(user)
    end

    it 'belongs to payment_method' do
      expect(payment_setup_session.payment_method).to eq(payment_method)
    end

    it 'can have a payment_source (CreditCard)' do
      credit_card = create(:credit_card, user: user)
      payment_setup_session.update!(payment_source: credit_card)
      expect(payment_setup_session.payment_source).to eq(credit_card)
      expect(payment_setup_session.payment_source_type).to eq('Spree::CreditCard')
    end
  end

  describe 'state machine' do
    describe '#process' do
      it 'transitions from pending to processing' do
        expect(payment_setup_session.process).to be true
        expect(payment_setup_session.status).to eq('processing')
      end
    end

    describe '#complete' do
      it 'transitions from pending to completed' do
        expect(payment_setup_session.complete).to be true
        expect(payment_setup_session.status).to eq('completed')
      end

      it 'transitions from processing to completed' do
        payment_setup_session.process
        expect(payment_setup_session.complete).to be true
        expect(payment_setup_session.status).to eq('completed')
      end
    end

    describe '#fail' do
      it 'transitions from pending to failed' do
        expect(payment_setup_session.fail).to be true
        expect(payment_setup_session.status).to eq('failed')
      end

      it 'transitions from processing to failed' do
        payment_setup_session.process
        expect(payment_setup_session.fail).to be true
        expect(payment_setup_session.status).to eq('failed')
      end
    end

    describe '#cancel' do
      it 'transitions from pending to canceled' do
        expect(payment_setup_session.cancel).to be true
        expect(payment_setup_session.status).to eq('canceled')
      end
    end

    describe '#expire' do
      it 'transitions from pending to expired' do
        expect(payment_setup_session.expire).to be true
        expect(payment_setup_session.status).to eq('expired')
      end
    end

    it 'does not allow transitioning from completed' do
      payment_setup_session.complete
      expect(payment_setup_session.cancel).to be false
      expect(payment_setup_session.status).to eq('completed')
    end

    it 'does not allow transitioning from failed' do
      payment_setup_session.fail
      expect(payment_setup_session.complete).to be false
      expect(payment_setup_session.status).to eq('failed')
    end
  end

  describe 'scopes' do
    describe '.active' do
      it 'includes pending sessions' do
        expect(described_class.active).to include(payment_setup_session)
      end

      it 'includes processing sessions' do
        payment_setup_session.process
        expect(described_class.active).to include(payment_setup_session)
      end

      it 'excludes completed sessions' do
        payment_setup_session.complete
        expect(described_class.active).not_to include(payment_setup_session)
      end

      it 'excludes expired sessions' do
        expired = create(:payment_setup_session, :expired, customer: user, payment_method: payment_method)
        expect(described_class.active).not_to include(expired)
      end
    end
  end

  describe '#prefixed_id' do
    it 'starts with pss_' do
      expect(payment_setup_session.prefixed_id).to start_with('pss_')
    end
  end

  describe 'soft delete' do
    it 'soft deletes with acts_as_paranoid' do
      payment_setup_session.destroy
      expect(described_class.with_deleted.find(payment_setup_session.id)).to be_present
      expect(described_class.find_by(id: payment_setup_session.id)).to be_nil
    end
  end

  describe 'events' do
    before do
      allow(Spree::Events).to receive(:enabled?).and_return(true)
      allow(Spree::Events).to receive(:publish)
    end

    describe 'lifecycle events' do
      it 'publishes payment_setup_session.created on create' do
        create(:payment_setup_session, customer: user, payment_method: payment_method)
        expect(Spree::Events).to have_received(:publish).with('payment_setup_session.created', anything, anything)
      end

      it 'publishes payment_setup_session.updated on update' do
        payment_setup_session.update!(external_id: 'new_id')
        expect(Spree::Events).to have_received(:publish).with('payment_setup_session.updated', anything, anything)
      end
    end

    describe 'state transition events' do
      it 'publishes payment_setup_session.processing on process' do
        payment_setup_session.process
        expect(Spree::Events).to have_received(:publish).with('payment_setup_session.processing', anything, anything)
      end

      it 'publishes payment_setup_session.completed on complete' do
        payment_setup_session.complete
        expect(Spree::Events).to have_received(:publish).with('payment_setup_session.completed', anything, anything)
      end

      it 'publishes payment_setup_session.failed on fail' do
        payment_setup_session.fail
        expect(Spree::Events).to have_received(:publish).with('payment_setup_session.failed', anything, anything)
      end

      it 'publishes payment_setup_session.canceled on cancel' do
        payment_setup_session.cancel
        expect(Spree::Events).to have_received(:publish).with('payment_setup_session.canceled', anything, anything)
      end

      it 'publishes payment_setup_session.expired on expire' do
        payment_setup_session.expire
        expect(Spree::Events).to have_received(:publish).with('payment_setup_session.expired', anything, anything)
      end

      it 'does not publish events when events are disabled' do
        allow(Spree::Events).to receive(:enabled?).and_return(false)

        payment_setup_session.complete

        expect(Spree::Events).not_to have_received(:publish).with('payment_setup_session.completed', anything, anything)
      end
    end
  end
end

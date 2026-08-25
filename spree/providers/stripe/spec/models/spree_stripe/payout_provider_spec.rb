require 'spec_helper'

RSpec.describe SpreeStripe::PayoutProvider do
  let(:store) { @default_store }
  let!(:gateway) { create(:stripe_gateway, store: store) }
  let(:seller) do
    create(:seller, :approved, store: store).tap do |record|
      record.set_payout_account_reference(SpreeStripe::PayoutProvider, 'acct_seller')
    end
  end
  let(:order) { create(:order, store: store, seller: seller, total: 100, currency: 'USD') }
  let(:seller_transfer) { create(:seller_transfer, seller: seller, order: order, amount: 42.5, currency: 'USD') }

  before do
    allow(Stripe::Transfer).to receive(:create).and_return(Stripe::StripeObject.construct_from(id: 'tr_1'))
  end

  describe '#transfer!' do
    it 'sends the seller their earning and records what Stripe called it' do
      described_class.new.transfer!(seller_transfer)

      expect(seller_transfer.reload).to be_completed
      expect(seller_transfer.reference).to eq('tr_1')
    end

    it 'sends whole minor units, so a divided charge still adds up' do
      expect(Stripe::Transfer).to receive(:create).
        with(hash_including(amount: 4250, currency: 'usd', destination: 'acct_seller'), anything).
        and_return(Stripe::StripeObject.construct_from(id: 'tr_1'))

      described_class.new.transfer!(seller_transfer)
    end

    # A retry after a timeout must find the movement it already made rather
    # than making a second one.
    it 'carries an idempotency key derived from the ledger row' do
      expect(Stripe::Transfer).to receive(:create).
        with(anything, hash_including(:idempotency_key)).
        and_return(Stripe::StripeObject.construct_from(id: 'tr_1'))

      described_class.new.transfer!(seller_transfer)
    end

    it 'refuses when the store has no Stripe payment method to pay from' do
      gateway.update!(active: false)

      expect { described_class.new.transfer!(seller_transfer) }.to raise_error(Spree::Core::GatewayError)
    end

    context 'when the customer paid by card' do
      # Funds the transfer from that charge, so it settles with the charge
      # rather than out of the marketplace's own balance.
      it 'names the charge as the funding source' do
        create(:payment, order: order, payment_method: gateway, status: 'completed',
                         response_code: 'ch_123', amount: 100)

        expect(Stripe::Transfer).to receive(:create).
          with(hash_including(source_transaction: 'ch_123'), anything).
          and_return(Stripe::StripeObject.construct_from(id: 'tr_1'))

        described_class.new.transfer!(seller_transfer)
      end
    end

    context 'when there is no charge to draw on' do
      it 'omits the funding source rather than sending a null one' do
        expect(Stripe::Transfer).to receive(:create) do |payload, _options|
          expect(payload).not_to have_key(:source_transaction)
          Stripe::StripeObject.construct_from(id: 'tr_1')
        end

        described_class.new.transfer!(seller_transfer)
      end
    end
  end

  describe '#pay!' do
    # Money on a connected account is settled by Stripe on that account's own
    # schedule, so a payout is confirmed by webhook rather than sent here.
    it 'sends nothing and leaves the settlement pending' do
      payout = create(:seller_payout, seller: seller)

      expect(Stripe::Payout).not_to receive(:create)

      described_class.new.pay!(payout)

      expect(payout.reload).to be_pending
    end
  end

  describe '.requires_payout_account?' do
    it 'is true — nothing can be sent to a seller without a connected account' do
      expect(described_class.requires_payout_account?).to be(true)
    end
  end

  describe '.available_for_store?' do
    it 'is false without an active Stripe payment method' do
      gateway.update!(active: false)

      expect(described_class.available_for_store?(store)).to be(false)
    end

    it 'is true when the store charges through Stripe' do
      expect(described_class.available_for_store?(store)).to be(true)
    end
  end
end

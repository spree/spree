require 'spec_helper'

# Reversals against Stripe rather than against a stub, so the recording shows
# what Stripe does when a refund pulls a seller's share back — including from
# a seller whose balance has already gone to their bank.
#
# Recorded on a test-mode platform with Connect turned on, against a connected
# account that is fully onboarded and can receive transfers:
#   STRIPE_SECRET_KEY=sk_test_... RECORD_VCR=1 pnpm test:rspec stripe <this file>
RSpec.describe SpreeStripe::PayoutProvider do
  let(:store) { @default_store }
  let!(:gateway) { create(:stripe_gateway, store: store) }
  let(:connected_account) { 'acct_1UE8TgCPyuszaKOY' }
  let(:seller) do
    create(:seller, :approved, store: store).tap do |record|
      record.set_payout_account_reference(described_class, connected_account)
    end
  end
  let(:order) { create(:order, store: store, seller: seller, total: 100, currency: 'USD') }
  let(:provider) { described_class.new }

  describe '#reverse!' do
    # A card whose funds are available at once, so the transfer can draw on
    # the charge straight away instead of waiting for it to settle.
    let(:charge_id) do
      Stripe::PaymentIntent.create(
        { amount: 10_000, currency: 'usd', payment_method: 'pm_card_bypassPending',
          payment_method_types: ['card'], confirm: true },
        gateway.api_options
      ).latest_charge
    end
    # Stripe keeps an idempotency key for a day and the test database repeats
    # ids, so rows that reach Stripe take ids no earlier recording used.
    let(:recording_id) { SecureRandom.random_number(1_000_000_000) }
    let(:earning) do
      create(:payment, order: order, payment_method: gateway, amount: order.total,
                       status: 'completed', metadata: { 'stripe_charge_id' => charge_id })
      provider.transfer!(
        create(:seller_transfer, id: recording_id, seller: seller, order: order, amount: 42.5, currency: 'USD',
                                 provider: described_class.provider_key)
      )
    end
    let(:reversal) do
      create(:seller_transfer, :reversal, id: recording_id + 1, seller: seller, order: order, reversed_from: earning,
                                          amount: -10.25, currency: 'USD', provider: described_class.provider_key)
    end

    before do
      earning
      Stripe::Refund.create({ charge: charge_id, amount: 2050 }, gateway.api_options)
    end

    context 'when the seller still holds the earning', vcr: { cassette_name: 'payout_provider_reverse_transfer' } do
      it "takes the seller's share back from the transfer that paid them" do
        provider.reverse!(reversal)

        expect(reversal.reload).to be_completed
        expect(reversal.reference).to start_with('trr_')
        expect(Stripe::Transfer.retrieve(earning.reference, gateway.api_options).amount_reversed).to eq(1025)
      end
    end

    # Nothing on the seller's account covers the reversal. The marketplace
    # carries their losses, so Stripe is expected to take the balance negative
    # rather than refuse.
    context 'when the seller has already been paid out',
            vcr: { cassette_name: 'payout_provider_reverse_transfer_after_payout' } do
      before do
        held = SpreeStripe::Units.to_stripe(provider.available_payout(seller, 'USD'), 'USD', payout: true)
        Stripe::Payout.create(
          { amount: held, currency: 'usd' }, gateway.api_options.merge(stripe_account: connected_account)
        )
      end

      it 'takes their balance below zero' do
        provider.reverse!(reversal)

        expect(reversal.reload).to be_completed
        expect(provider.available_payout(seller, 'USD')).to eq(-10.25)
      end
    end
  end
end

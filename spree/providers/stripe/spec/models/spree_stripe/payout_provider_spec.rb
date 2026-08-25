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
    let(:payout) { create(:seller_payout, seller: seller, amount: 42.5, currency: 'USD') }

    before do
      allow(Stripe::Payout).to receive(:create).and_return(Stripe::StripeObject.construct_from(id: 'po_1'))
    end

    it 'sends the settlement to the seller’s bank' do
      expect(Stripe::Payout).to receive(:create).
        with(hash_including(amount: 4250, currency: 'usd'), anything).
        and_return(Stripe::StripeObject.construct_from(id: 'po_1'))

      described_class.new.pay!(payout)
    end

    # The money is the seller's own balance, so the payout is made as them.
    it 'acts as the connected account' do
      expect(Stripe::Payout).to receive(:create).
        with(anything, hash_including(stripe_account: 'acct_seller')).
        and_return(Stripe::StripeObject.construct_from(id: 'po_1'))

      described_class.new.pay!(payout)
    end

    # Stored now, so the confirming webhook matches on Stripe's own id rather
    # than guessing which settlement it meant.
    it 'keeps Stripe’s id for the settlement' do
      described_class.new.pay!(payout)

      expect(payout.reload.reference).to eq('po_1')
    end

    # A settlement is a claim about the outside world whoever makes it.
    it 'leaves it pending until the bank confirms' do
      described_class.new.pay!(payout)

      expect(payout.reload).to be_pending
    end

    it 'carries an idempotency key, so a retry finds the payout it made' do
      expect(Stripe::Payout).to receive(:create).
        with(anything, hash_including(:idempotency_key)).
        and_return(Stripe::StripeObject.construct_from(id: 'po_1'))

      described_class.new.pay!(payout)
    end

    it 'refuses a seller who holds no Stripe account' do
      other = create(:seller_payout, seller: create(:seller, :approved, store: store))

      expect { described_class.new.pay!(other) }.to raise_error(Spree::Core::GatewayError)
    end
  end

  describe '#onboarding_state' do
    def account(payouts_enabled:, disabled_reason: nil, errors: [])
      Stripe::StripeObject.construct_from(
        id: 'acct_seller',
        payouts_enabled: payouts_enabled,
        requirements: { disabled_reason: disabled_reason, errors: errors }
      )
    end

    def stub_account(**attrs)
      allow(Stripe::Account).to receive(:retrieve).and_return(account(**attrs))
    end

    it 'has nothing to say about a seller who can be paid' do
      stub_account(payouts_enabled: true)

      expect(described_class.new.onboarding_state(seller)).to be_nil
    end

    it 'asks the seller to finish when Stripe is waiting on them' do
      stub_account(payouts_enabled: false, disabled_reason: 'requirements.past_due')

      expect(described_class.new.onboarding_state(seller)).to eq(:action)
    end

    # Nobody can hurry a review, so this must not read as "go and finish".
    it 'reports a review in progress as pending' do
      stub_account(payouts_enabled: false, disabled_reason: 'requirements.pending_verification')

      expect(described_class.new.onboarding_state(seller)).to eq(:pending)
    end

    it 'reports an account under review as pending' do
      stub_account(payouts_enabled: false, disabled_reason: 'under_review')

      expect(described_class.new.onboarding_state(seller)).to eq(:pending)
    end

    it 'reports a refusal as rejected' do
      stub_account(payouts_enabled: false, disabled_reason: 'rejected.fraud')

      expect(described_class.new.onboarding_state(seller)).to eq(:rejected)
    end

    # A checklist asking why it is stuck must not take the page down because
    # Stripe is unreachable.
    it 'stays quiet when Stripe cannot be reached' do
      allow(Stripe::Account).to receive(:retrieve).and_raise(Stripe::APIError.new('boom'))

      expect(described_class.new.onboarding_state(seller)).to be_nil
    end

    it 'has nothing to say about a seller who holds no account' do
      other = create(:seller, :approved, store: store)

      expect(described_class.new.onboarding_state(other)).to be_nil
    end
  end

  describe '#onboarding_message' do
    it 'passes on what Stripe said, so the seller knows what to fix' do
      allow(Stripe::Account).to receive(:retrieve).and_return(
        Stripe::StripeObject.construct_from(
          id: 'acct_seller',
          payouts_enabled: false,
          requirements: {
            disabled_reason: 'requirements.past_due',
            errors: [{ code: 'verification_document_not_readable', reason: 'The image supplied isn’t readable.' }]
          }
        )
      )

      expect(described_class.new.onboarding_message(seller)).to eq('The image supplied isn’t readable.')
    end

    # A field simply not provided yet has no error and nothing to say.
    it 'says nothing when Stripe reported no failure' do
      allow(Stripe::Account).to receive(:retrieve).and_return(
        Stripe::StripeObject.construct_from(
          id: 'acct_seller', payouts_enabled: false,
          requirements: { disabled_reason: 'requirements.past_due', errors: [] }
        )
      )

      expect(described_class.new.onboarding_message(seller)).to be_nil
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

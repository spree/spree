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

    # A seller whose commission met their sale earns nothing. The row is
    # true, and Stripe refuses the amount — asking it would park the row and
    # have the retry job ask again forever.
    it 'sends nothing when there is nothing to send' do
      nothing = create(:seller_transfer, seller: seller, amount: 0, currency: 'USD',
                                         order: create(:order, store: store, seller: seller))

      expect(Stripe::Transfer).not_to receive(:create)

      described_class.new.transfer!(nothing)

      expect(nothing.reload).to be_completed
    end

    it 'refuses when the store has no Stripe payment method to pay from' do
      gateway.update!(active: false)

      expect { described_class.new.transfer!(seller_transfer) }.to raise_error(Spree::Core::GatewayError)
    end

    context 'when the customer paid by card' do
      # Funds the transfer from that charge, so it settles with the charge
      # rather than out of the marketplace's own balance.
      # Stripe funds a transfer from a charge. `response_code` holds the
      # payment intent that produced it, which Stripe cannot use here — the
      # charge is recorded on the payment when its session completes.
      it 'names the charge as the funding source' do
        create(:payment, order: order, payment_method: gateway, status: 'completed',
                         response_code: 'pi_123', amount: 100,
                         metadata: { 'stripe_charge_id' => 'ch_123' })

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

    # Stripe may have created the payout before the answer was lost. Core has
    # to hear that the outcome is unknown, because its reaction is the opposite
    # of the one a refusal deserves.
    context 'when the answer is lost on the way back' do
      it 'says so, rather than reporting a refusal' do
        allow(Stripe::Payout).to receive(:create).and_raise(Stripe::APIConnectionError, 'timed out')

        expect { described_class.new.pay!(payout) }.
          to raise_error(Spree::Core::AmbiguousGatewayError)
      end

      # Reusing a key with different parameters means Stripe already holds a
      # payout under it — so something moved, whatever this call thought.
      it 'says the same when Stripe rejects a reused key' do
        allow(Stripe::Payout).to receive(:create).and_raise(Stripe::IdempotencyError, 'key reused')

        expect { described_class.new.pay!(payout) }.
          to raise_error(Spree::Core::AmbiguousGatewayError)
      end
    end

    # A refusal is definite, and core is right to release the earnings for it.
    it 'reports an outright refusal as an ordinary failure' do
      allow(Stripe::Payout).to receive(:create).
        and_raise(Stripe::InvalidRequestError.new('insufficient funds', 'amount'))

      expect { described_class.new.pay!(payout) }.to raise_error(Stripe::InvalidRequestError)
    end
  end

  # The column is a cache of what a webhook last said, and a webhook can fail
  # to arrive — an endpoint never registered, a delivery dropped. A seller who
  # has finished onboarding must not be left looking at a checklist that says
  # they have not while Stripe is ready to pay them.
  describe '#onboarded?' do
    def stub_account(payouts_enabled:)
      allow(Stripe::Account).to receive(:retrieve).and_return(
        Stripe::StripeObject.construct_from(
          id: 'acct_seller', payouts_enabled: payouts_enabled, requirements: { disabled_reason: nil, errors: [] }
        )
      )
    end

    it 'believes Stripe over a column no webhook has written' do
      seller.update!(payouts_enabled_at: nil)
      stub_account(payouts_enabled: true)

      expect(described_class.new.onboarded?(seller)).to be(true)
    end

    it 'believes Stripe when it withdraws the capability' do
      seller.update!(payouts_enabled_at: Time.current)
      stub_account(payouts_enabled: false)

      expect(described_class.new.onboarded?(seller)).to be(false)
    end

    # Stripe being unreachable must not read as "this seller cannot be paid".
    it 'falls back to what we were last told when Stripe cannot be reached' do
      seller.update!(payouts_enabled_at: Time.current)
      allow(Stripe::Account).to receive(:retrieve).and_raise(Stripe::APIError.new('boom'))

      expect(described_class.new.onboarded?(seller)).to be(true)
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

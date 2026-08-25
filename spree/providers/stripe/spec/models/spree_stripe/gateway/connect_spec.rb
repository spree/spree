require 'spec_helper'

RSpec.describe SpreeStripe::Gateway::Connect do
  let(:store) { @default_store }
  let(:gateway) { create(:stripe_gateway, store: store) }
  let(:seller) do
    create(:seller, :approved, store: store).tap do |record|
      record.set_payout_account_reference(SpreeStripe::PayoutProvider, 'acct_seller')
    end
  end
  let(:headers) { { 'HTTP_STRIPE_SIGNATURE' => 'sig_test' } }
  let(:raw_body) { '{"id": "evt_test"}' }

  before { gateway.preferences = gateway.preferences.merge(connect_webhook_signing_secret: 'whsec_connect') }

  def stripe_event(type, object, account: nil)
    Stripe::StripeObject.construct_from({ type: type, account: account, data: { object: object } }.compact)
  end

  describe '#handle_payout_webhook' do
    context 'account.updated' do
      it 'lets a seller be paid once Stripe says the account can receive transfers' do
        allow(Stripe::Webhook).to receive(:construct_event).and_return(
          stripe_event('account.updated', { id: 'acct_seller', payouts_enabled: true })
        )

        expect { gateway.handle_payout_webhook(raw_body, headers) }.
          to change { seller.reload.payouts_enabled_at }.from(nil)
      end

      # A seller whose documents expire stops being payable, and the ledger has
      # to stop crediting them rather than promise money nothing can send.
      it 'stops a seller being paid when Stripe withdraws the capability' do
        seller.update!(payouts_enabled_at: 2.days.ago)
        allow(Stripe::Webhook).to receive(:construct_event).and_return(
          stripe_event('account.updated', { id: 'acct_seller', payouts_enabled: false })
        )

        gateway.handle_payout_webhook(raw_body, headers)

        expect(seller.reload.payouts_enabled_at).to be_nil
      end

      it 'leaves an already-payable seller alone rather than restamping them' do
        stamped = 3.days.ago.round
        seller.update!(payouts_enabled_at: stamped)
        allow(Stripe::Webhook).to receive(:construct_event).and_return(
          stripe_event('account.updated', { id: 'acct_seller', payouts_enabled: true })
        )

        gateway.handle_payout_webhook(raw_body, headers)

        expect(seller.reload.payouts_enabled_at).to be_within(1.second).of(stamped)
      end

      it 'ignores an account belonging to no seller here' do
        allow(Stripe::Webhook).to receive(:construct_event).and_return(
          stripe_event('account.updated', { id: 'acct_stranger', payouts_enabled: true })
        )

        expect { gateway.handle_payout_webhook(raw_body, headers) }.not_to raise_error
      end
    end

    context 'payout.paid' do
      let!(:payout) { create(:seller_payout, seller: seller, currency: 'USD', reference: 'po_1') }

      it 'completes the settlement the seller was owed' do
        allow(Stripe::Webhook).to receive(:construct_event).and_return(
          stripe_event('payout.paid', { id: 'po_1', currency: 'usd', amount: 2_000 }, account: 'acct_seller')
        )

        gateway.handle_payout_webhook(raw_body, headers)

        expect(payout.reload).to be_completed
        expect(payout.reference).to eq('po_1')
      end

      # Spree created the payout and stored Stripe's id for it, so an event
      # naming an id we hold nothing for is about somebody else's payout —
      # guessing which of ours it meant would complete the wrong one.
      it 'leaves settlements alone when it names an id we do not hold' do
        allow(Stripe::Webhook).to receive(:construct_event).and_return(
          stripe_event('payout.paid', { id: 'po_elsewhere', currency: 'usd', amount: 2_000 }, account: 'acct_seller')
        )

        gateway.handle_payout_webhook(raw_body, headers)

        expect(payout.reload).to be_pending
      end
    end

    context 'payout.failed' do
      let!(:payout) { create(:seller_payout, seller: seller, currency: 'USD', reference: 'po_1') }

      before do
        allow(Stripe::Webhook).to receive(:construct_event).and_return(
          stripe_event('payout.failed', { id: 'po_1', currency: 'usd', amount: 2_000 }, account: 'acct_seller')
        )
      end

      it 'marks the settlement failed so it is visible rather than silently stuck' do
        gateway.handle_payout_webhook(raw_body, headers)

        expect(payout.reload).to be_failed
      end

      # Left stamped to a failed settlement the earnings are unreachable: the
      # sweep only ever collects unstamped rows, while the balance still says
      # the seller is owed them.
      it 'releases the earnings so the next sweep is the retry' do
        create(:seller_transfer, :completed, seller: seller, payout: payout, amount: 40,
                                             order: create(:order, store: store, seller: seller))

        gateway.handle_payout_webhook(raw_body, headers)

        expect(seller.seller_transfers.unsettled.sum(:amount)).to eq(40)
      end
    end

    # Stripe redelivers on any non-2xx or timeout. Without matching on its own
    # payout id, a second delivery would skip the settlement it already
    # completed and land on the next one still owed.
    context 'when payout.paid is delivered twice' do
      let!(:first) { create(:seller_payout, seller: seller, currency: 'USD', amount: 40, reference: 'po_1') }
      let!(:second) { create(:seller_payout, seller: seller, currency: 'USD', amount: 40, reference: 'po_2') }

      before do
        allow(Stripe::Webhook).to receive(:construct_event).and_return(
          stripe_event('payout.paid', { id: 'po_1', currency: 'usd', amount: 4_000 }, account: 'acct_seller')
        )
      end

      it 'leaves the settlement it did not name alone' do
        gateway.handle_payout_webhook(raw_body, headers)
        gateway.handle_payout_webhook(raw_body, headers)

        expect(first.reload).to be_completed
        expect(second.reload).to be_pending
      end
    end

    it 'refuses an unsigned report — it could otherwise mark a seller payable' do
      allow(Stripe::Webhook).to receive(:construct_event).
        and_raise(Stripe::SignatureVerificationError.new('bad', 'sig_test'))

      expect { gateway.handle_payout_webhook(raw_body, headers) }.
        to raise_error(Spree::PaymentMethod::WebhookSignatureError)
    end

    # The two endpoints carry different traffic signed with different secrets,
    # so a payment event verified against the payment secret must not verify
    # here.
    it 'verifies against the Connect secret rather than the payment one' do
      expect(Stripe::Webhook).to receive(:construct_event).with(raw_body, 'sig_test', 'whsec_connect').
        and_return(stripe_event('account.updated', { id: 'acct_seller', payouts_enabled: true }))

      gateway.handle_payout_webhook(raw_body, headers)
    end
  end

  describe '#create_connect_account_link' do
    it 'creates an Express account for a seller who has none, then links to onboarding' do
      seller = create(:seller, :approved, store: store)
      allow(Stripe::Account).to receive(:create).and_return(Stripe::StripeObject.construct_from(id: 'acct_new'))
      allow(Stripe::AccountLink).to receive(:create).
        and_return(Stripe::StripeObject.construct_from(url: 'https://connect.stripe.com/setup/x'))

      url = gateway.create_connect_account_link(seller: seller, refresh_url: 'https://s/r', return_url: 'https://s/d')

      expect(url).to eq('https://connect.stripe.com/setup/x')
      expect(seller.reload.payout_account_reference(SpreeStripe::PayoutProvider)).to eq('acct_new')
    end

    it 'reuses the account a seller already holds' do
      allow(Stripe::AccountLink).to receive(:create).
        and_return(Stripe::StripeObject.construct_from(url: 'https://connect.stripe.com/setup/y'))

      expect(Stripe::Account).not_to receive(:create)

      gateway.create_connect_account_link(seller: seller, refresh_url: 'https://s/r', return_url: 'https://s/d')
    end
  end

  describe 'the account a seller is onboarded to' do
    let(:new_seller) { create(:seller, :approved, store: store) }

    before do
      allow(Stripe::AccountLink).to receive(:create).
        and_return(Stripe::StripeObject.construct_from(url: 'https://connect.stripe.com/setup/x'))
      allow(Stripe::Account).to receive(:create).and_return(Stripe::StripeObject.construct_from(id: 'acct_new'))
      store.update!(default_country_code: 'US')
    end

    def onboard(seller = new_seller)
      gateway.create_connect_account_link(seller: seller, refresh_url: 'https://s/r', return_url: 'https://s/d')
    end

    # Spree decides when a seller is settled, so Stripe must not also be paying
    # their balance out on a schedule of its own.
    it 'never pays out on a schedule of its own' do
      expect(Stripe::Account).to receive(:create).
        with(hash_including(settings: { payouts: { schedule: { interval: 'manual' } } }), anything).
        and_return(Stripe::StripeObject.construct_from(id: 'acct_new'))

      onboard
    end

    # Stripe would otherwise assume the platform's country, and a seller ends
    # up with an account no local bank can receive.
    it 'is created where the seller trades' do
      new_seller.update!(billing_address: create(:address, country_code: 'FR', state_code: nil))

      expect(Stripe::Account).to receive(:create).
        with(hash_including(country: 'FR'), anything).
        and_return(Stripe::StripeObject.construct_from(id: 'acct_new'))

      onboard
    end

    it 'falls back to the marketplace’s own country' do
      expect(Stripe::Account).to receive(:create).
        with(hash_including(country: 'US'), anything).
        and_return(Stripe::StripeObject.construct_from(id: 'acct_new'))

      onboard
    end

    # Paying a seller abroad is a different agreement, and without it Stripe
    # refuses to create the account at all.
    it 'accepts the recipient agreement for a seller abroad' do
      new_seller.update!(billing_address: create(:address, country_code: 'FR', state_code: nil))

      expect(Stripe::Account).to receive(:create).
        with(hash_including(tos_acceptance: { service_agreement: 'recipient' }), anything).
        and_return(Stripe::StripeObject.construct_from(id: 'acct_new'))

      onboard
    end

    it 'does not ask for it at home' do
      expect(Stripe::Account).to receive(:create) do |params, _options|
        expect(params).not_to have_key(:tos_acceptance)
        Stripe::StripeObject.construct_from(id: 'acct_new')
      end

      onboard
    end
  end

  describe '#connect_webhook_url' do
    it 'is its own endpoint, separate from the payment one' do
      expect(gateway.connect_webhook_url).to end_with("/api/v3/webhooks/payouts/#{gateway.prefixed_id}")
      expect(gateway.connect_webhook_url).not_to eq(gateway.webhook_url)
    end
  end
end

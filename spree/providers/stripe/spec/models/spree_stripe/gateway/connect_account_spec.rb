require 'spec_helper'

# The Connect account contract, against Stripe rather than against a stub.
#
# The rest of the Connect specs stub `Stripe::Account.create` and assert on the
# hash we were about to send, which cannot tell us whether Stripe accepts it —
# a payload carrying both `type` and `controller` passed every one of those
# while failing every real request. These record what Stripe actually said.
RSpec.describe SpreeStripe::Gateway::Connect do
  let(:store) { @default_store }
  let(:gateway) { create(:stripe_gateway, store: store) }
  let(:seller) { create(:seller, :approved, store: store, name: 'Sparks Audio') }

  describe 'creating a seller their account' do
    it 'opens an Express account Stripe accepts', vcr: { cassette_name: 'connect_create_express_account' } do
      url = gateway.create_connect_account_link(
        seller: seller,
        refresh_url: 'https://example.test/onboarding',
        return_url: 'https://example.test/onboarding'
      )

      expect(url).to start_with('https://connect.stripe.com/')
      expect(seller.reload.payout_account_reference(SpreeStripe::PayoutProvider)).to start_with('acct_')
    end

    # Stripe reads the properties back rather than the preset, so the account
    # is described by what it can do rather than by a type name.
    it 'gives the platform the fees and the losses', vcr: { cassette_name: 'connect_create_express_account_shape' } do
      gateway.create_connect_account_link(
        seller: seller,
        refresh_url: 'https://example.test/onboarding',
        return_url: 'https://example.test/onboarding'
      )

      account = Stripe::Account.retrieve(
        seller.reload.payout_account_reference(SpreeStripe::PayoutProvider), gateway.api_options
      )

      expect(account.controller.fees.payer).to eq('application')
      expect(account.controller.losses.payments).to eq('application')
      expect(account.controller.stripe_dashboard.type).to eq('express')
    end

    # Spree decides when a seller is settled, so Stripe must not also be
    # paying their balance out on a clock of its own.
    it 'leaves the payout schedule to Spree', vcr: { cassette_name: 'connect_create_express_account_manual_payouts' } do
      gateway.create_connect_account_link(
        seller: seller,
        refresh_url: 'https://example.test/onboarding',
        return_url: 'https://example.test/onboarding'
      )

      account = Stripe::Account.retrieve(
        seller.reload.payout_account_reference(SpreeStripe::PayoutProvider), gateway.api_options
      )

      expect(account.settings.payouts.schedule.interval).to eq('manual')
    end
  end

  describe 'a seller who already holds an account' do
    it 'mints a fresh link without opening a second one', vcr: { cassette_name: 'connect_relink_existing_account' } do
      first = gateway.create_connect_account_link(
        seller: seller,
        refresh_url: 'https://example.test/onboarding',
        return_url: 'https://example.test/onboarding'
      )
      account_id = seller.reload.payout_account_reference(SpreeStripe::PayoutProvider)

      second = gateway.create_connect_account_link(
        seller: seller.reload,
        refresh_url: 'https://example.test/onboarding',
        return_url: 'https://example.test/onboarding'
      )

      expect(second).to start_with('https://connect.stripe.com/')
      expect(second).not_to eq(first)
      expect(seller.reload.payout_account_reference(SpreeStripe::PayoutProvider)).to eq(account_id)
    end
  end
end

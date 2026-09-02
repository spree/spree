require 'spec_helper'

RSpec.describe SpreeAvalara::ValidateCheckoutAddress do
  subject(:handler) { described_class.new }

  let!(:integration) do
    create(:avalara_integration, :active, store: @default_store, preferred_address_validation_enabled: true)
  end
  let(:address) { create(:address, city: 'Seattle', state_code: 'WA', country_code: 'US', zipcode: '98109') }
  let(:cart) { create(:cart, store: @default_store, ship_address: address, bill_address: address) }
  # A plain double on purpose: Spree::Workflow generates its argument readers at
  # run time, so a verifying double cannot see `cart`.
  let(:workflow) { double('Spree::Carts::Complete', cart: cart, errors: errors) }
  let(:errors) { ActiveModel::Errors.new(Spree::Cart.new) }
  let(:validator) { instance_double(SpreeAvalara::Address::Validate) }

  def resolved
    SpreeAvalara::Address::Validate::Result.new
  end

  def unresolved(transport: false)
    SpreeAvalara::Address::Validate::Result.new(
      error: SpreeAvalara::Address::Validate::Failure.new(messages: ['not deliverable'], transport: transport)
    )
  end

  before do
    allow(SpreeAvalara::Address::Validate).to receive(:new).and_return(validator)
    allow(workflow).to receive(:reject!)
  end

  it 'lets a resolvable address through' do
    allow(validator).to receive(:call).and_return(resolved)

    handler.call(workflow)

    expect(workflow).not_to have_received(:reject!)
  end

  it 'vetoes completion when Avalara cannot resolve the address' do
    allow(validator).to receive(:call).and_return(unresolved)

    handler.call(workflow)

    expect(workflow).to have_received(:reject!)
    expect(errors[:base]).to include('not deliverable')
  end

  # Importing Avalara's downtime into checkout is worse than accepting an
  # unverified address; only estimate fails closed.
  it 'fails open when Avalara cannot be reached' do
    allow(validator).to receive(:call).and_return(unresolved(transport: true))

    handler.call(workflow)

    expect(workflow).not_to have_received(:reject!)
  end

  describe 'guards' do
    before { allow(validator).to receive(:call).and_return(unresolved) }

    it 'does nothing when the merchant has not enabled address validation' do
      integration.update!(preferred_address_validation_enabled: false)

      handler.call(workflow)

      expect(validator).not_to have_received(:call)
    end

    it 'does nothing without a connected integration' do
      integration.update!(active: false)

      handler.call(workflow)

      expect(validator).not_to have_received(:call)
    end

    it 'does nothing when the sale has no tax address yet' do
      cart.update!(ship_address: nil, bill_address: nil)

      handler.call(workflow)

      expect(validator).not_to have_received(:call)
    end

    it 'does nothing outside the countries Avalara covers' do
      cart.update!(ship_address: create(:address, country_code: 'DE'), bill_address: nil)

      handler.call(workflow)

      expect(validator).not_to have_received(:call)
    end
  end

  # A mistyped hook key never fires and never complains, so boot checks it —
  # after eager loading, which is when every workflow has registered itself.
  it 'is registered against a hook that exists' do
    Rails.application.eager_load!

    expect(Spree.hooks.for('carts.complete.validate').map(&:class)).to include(described_class)
    expect(Spree::Carts::Complete.declared_hooks).to include(:validate)
    expect { Spree.hooks.validate! }.not_to raise_error
  end
end

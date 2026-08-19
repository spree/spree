require 'spec_helper'

RSpec.describe SpreeStripe::CustomerPresenter do
  subject(:payload) { described_class.new(name: name, email: email, address: address).call }

  let(:name) { 'Jane Moe' }
  let(:email) { 'jane@example.com' }
  let(:address) do
    create(
      :address,
      address1: '100 California Street',
      address2: 'Apt 1',
      city: 'San Francisco',
      zipcode: '94111',
      country: Spree::Country.by_iso('US'),
      state: Spree::Country.by_iso('US').states.find { |state| state.abbr == 'CA' }
    )
  end

  it 'sends the name and email' do
    expect(payload).to include(name: name, email: email)
  end

  # Stripe expects ISO codes here, matching the intent's shipping payload —
  # full country and subdivision names degrade its location resolution.
  it 'sends the address as ISO codes' do
    expect(payload[:address]).to include(
      city: 'San Francisco',
      line1: '100 California Street',
      line2: 'Apt 1',
      postal_code: '94111',
      country: 'US',
      state: 'CA'
    )
  end

  context 'when the address has no subdivision code' do
    let(:address) do
      build(:address, country: Spree::Country.by_iso('GB'), state: nil, state_name: 'Greater London')
    end

    it 'falls back to the free-text state name' do
      expect(payload[:address][:state]).to eq('Greater London')
    end
  end

  context 'without an address' do
    let(:address) { nil }

    it 'omits the address entirely' do
      expect(payload).not_to have_key(:address)
    end
  end

  context 'without a name or email' do
    let(:name) { nil }
    let(:email) { nil }

    it 'omits them rather than sending blanks' do
      expect(payload.keys).not_to include(:name, :email)
    end
  end
end

require 'spec_helper'

RSpec.describe SpreeAvalara::AddressPresenter do
  it 'has nothing to describe without a source' do
    expect(described_class.new(nil).call).to be_nil
  end

  it 'maps an address onto AvaTax location fields' do
    address = build(:address, address1: '410 Terry Ave N', address2: 'Floor 3', city: 'Seattle',
                              state_code: 'WA', country_code: 'US', zipcode: '98109')

    expect(described_class.new(address).call).to eq(
      line1: '410 Terry Ave N', line2: 'Floor 3', city: 'Seattle',
      region: 'WA', country: 'US', postalCode: '98109'
    )
  end

  # A stock location is the other side of the same supply and answers the same
  # readers, so origins present identically.
  it 'maps a stock location the same way' do
    location = build(:stock_location, address1: '2000 Main Street', city: 'Irvine',
                                      state_code: 'CA', country_code: 'US', zipcode: '92614')

    expect(described_class.new(location).call).to include(
      line1: '2000 Main Street', city: 'Irvine', region: 'CA', country: 'US', postalCode: '92614'
    )
  end

  it 'omits fields the record does not carry' do
    address = build(:address, address2: nil)

    expect(described_class.new(address).call.keys).not_to include(:line2)
  end
end

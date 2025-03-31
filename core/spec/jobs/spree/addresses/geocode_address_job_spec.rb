require 'spec_helper'

RSpec.describe Spree::Addresses::GeocodeAddressJob do
  subject(:geocode_address) { described_class.new.perform(address.id) }

  let(:address) do
    create(
      :address,
      address1: '100 California Street',
      city: 'San Francisco',
      zipcode: '94111',
      state: california_state,
      country: usa_country
    )
  end

  let(:usa_country) { Spree::Country.find_by(iso: 'US') || create(:usa_country) }
  let(:california_state) { create(:state, name: 'California', abbr: 'CA', country: usa_country) }

  let(:geocoder_coordinates) { [37.8, -122.4] }

  before do
    allow(Geocoder).to receive(:coordinates).
      with(address.geocoder_address, country: address.country_iso3).
      and_return(geocoder_coordinates)
  end

  it 'geocodes the address' do
    geocode_address

    expect(address.reload.latitude).to be_present
    expect(address.longitude).to be_present
  end

  context 'when the address cannot be geocoded' do
    let(:geocoder_coordinates) { nil }

    it 'handles the error' do
      expect(Rails.error).to receive(:report).with(
        Spree::Addresses::GeocodeAddressError.new("Cannot geocode address ID: #{address.id}"),
        handled: false,
        context: { address_id: address.id },
        source: 'spree.core'
      )

      geocode_address

      expect(address.reload.latitude).to be_nil
      expect(address.longitude).to be_nil
    end
  end
end

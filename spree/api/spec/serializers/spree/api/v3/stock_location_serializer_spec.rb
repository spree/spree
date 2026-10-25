require 'spec_helper'

RSpec.describe Spree::Api::V3::StockLocationSerializer do
  let(:stock_location) { build(:stock_location, country_code: 'US', state_code: 'DC') }

  subject { described_class.new(stock_location, params: { store: @default_store, currency: 'USD' }).to_h }

  it 'keeps the 5.6 names for the country and state codes until 6.1' do
    expect(subject).to include('country_code' => 'US', 'country_iso' => 'US', 'state_code' => 'DC', 'state_abbr' => 'DC')
  end

  it 'leaves the deprecated names out of the Admin and Seller APIs' do
    [Spree::Api::V3::Admin::StockLocationSerializer, Spree::Api::V3::Seller::StockLocationSerializer].each do |serializer|
      expect(serializer.new(stock_location, params: { store: @default_store, currency: 'USD' }).to_h.keys).
        not_to include('country_iso', 'state_abbr')
    end
  end
end

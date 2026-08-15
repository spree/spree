require 'spec_helper'

# Exercised through hosts rather than an anonymous model — the declarations
# these models make are the contract.
describe Spree::HasIsoGeography, type: :model do
  describe 'country_code validation' do
    it 'accepts a known code in any case' do
      stock_location = build(:stock_location, country: nil, state: nil)
      stock_location.country_code = 'us'

      expect(stock_location).to be_valid
      expect(stock_location.country_code).to eq('US')
    end

    it 'rejects a code nothing recognises' do
      stock_location = build(:stock_location, country: nil, state: nil)
      stock_location.country_code = 'ZZ'

      expect(stock_location).not_to be_valid
      expect(stock_location.errors[:country_code]).to be_present
    end

    it 'leaves a blank code to the presence rules of the host' do
      expect(build(:stock_location, country: nil, state: nil)).to be_valid
    end

    it 'guards country-only hosts too' do
      market_country = Spree::MarketCountry.new(market: create(:market), country_code: 'ZZ')

      expect(market_country).not_to be_valid
      expect(market_country.errors[:country_code]).to be_present
    end
  end

  describe 'state_code validation' do
    it 'accepts a subdivision of the country' do
      expect(build(:stock_location, country_code: 'US', state_code: 'NY')).to be_valid
    end

    it 'accepts a retired code that resolves through its successor' do
      stock_location = build(:stock_location, country: nil, state: nil, country_code: 'IN', state_code: 'OR')

      expect(stock_location).to be_valid
    end

    it 'rejects a code that is no subdivision of the country' do
      stock_location = build(:stock_location, country: nil, state: nil, country_code: 'US', state_code: 'ZZ')

      expect(stock_location).not_to be_valid
      expect(stock_location.errors[:state_code]).to be_present
    end

    it 'checks nothing without a country — a subdivision code is only unique within one' do
      expect(build(:stock_location, country: nil, state: nil, state_code: 'NY')).to be_valid
    end

    it 'reports only the country when both codes are unrecognisable' do
      stock_location = build(:stock_location, country: nil, state: nil, country_code: 'ZZ', state_code: 'QQ')

      expect(stock_location).not_to be_valid
      expect(stock_location.errors[:country_code]).to be_present
      expect(stock_location.errors[:state_code]).to be_blank
    end
  end

  describe 'historical rows' do
    # The registry's curation can shift under stored rows; a code that stops
    # resolving must not wedge the record on unrelated updates.
    it 'stays updatable when a stored code no longer resolves' do
      stock_location = create(:stock_location)
      stock_location.update_columns(country_code: 'ZZ', state_code: 'QQ')

      stock_location.reload
      expect(stock_location.update(name: 'Renamed warehouse')).to be(true)
    end

    it 'validates again once the code itself changes' do
      stock_location = create(:stock_location)
      stock_location.update_columns(country_code: 'ZZ')

      stock_location.reload
      expect(stock_location.update(country_code: 'YY')).to be(false)
      expect(stock_location.errors[:country_code]).to be_present
    end
  end
end

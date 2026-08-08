require 'spec_helper'

# The migrator lives in the rake file (it is a one-release upgrade step, not
# engine infrastructure), so load it the way the task does.
unless defined?(Spree::CountryStateIsoMigrator)
  load Spree::Core::Engine.root.join('lib', 'tasks', 'migrate_country_state_isos.rake')
end

RSpec.describe Spree::CountryStateIsoMigrator do
  subject(:migrate) { described_class.new.call }

  let(:country) { create(:country, iso: 'PL', iso3: 'POL', name: 'Poland', iso_name: 'POLAND') }
  let(:state) { create(:state, country: country, abbr: 'DS', name: 'Dolnoslaskie') }

  # The columns are filled by the task, so clear whatever created the record
  # populated to prove the backfill is what put them back.
  def clear_iso_columns(record, *columns)
    record.update_columns(columns.index_with(nil))
    record.reload
  end

  describe 'addresses' do
    let(:address) { create(:address, country: country, state: state) }

    it 'names the country and state by code' do
      clear_iso_columns(address, :country_iso, :state_abbr)

      migrate

      expect(address.reload.country_iso).to eq('PL')
      expect(address.state_abbr).to eq('DS')
    end

    it 'leaves an address with no state alone' do
      stateless = create(:address, country: country, state: nil, state_name: 'Somewhere')
      clear_iso_columns(stateless, :country_iso, :state_abbr)

      migrate

      expect(stateless.reload.country_iso).to eq('PL')
      expect(stateless.state_abbr).to be_nil
    end
  end

  describe 'delivery zone members' do
    let(:delivery_zone) { create(:delivery_zone) }

    it 'names a country member by code' do
      member = delivery_zone.members.create!(member_type: 'country', country: country)
      clear_iso_columns(member, :country_iso, :state_abbr)

      migrate

      expect(member.reload.country_iso).to eq('PL')
    end

    # A subdivision code is only unique within its country, so a state member
    # has to record both halves or it cannot be resolved on its own.
    it 'gives a state member its country as well' do
      member = delivery_zone.members.create!(member_type: 'state', state: state)
      clear_iso_columns(member, :country_iso, :state_abbr)

      migrate

      expect(member.reload.state_abbr).to eq('DS')
      expect(member.country_iso).to eq('PL')
    end
  end

  describe 'other consumers' do
    it 'names a market country by code' do
      market = create(:market, store: @default_store, countries: [country])
      market_country = market.market_countries.first
      clear_iso_columns(market_country, :country_iso)

      migrate

      expect(market_country.reload.country_iso).to eq('PL')
    end

    it 'names a stock location country and state by code' do
      stock_location = create(:stock_location, country: country, state: state)
      clear_iso_columns(stock_location, :country_iso, :state_abbr)

      migrate

      expect(stock_location.reload.country_iso).to eq('PL')
      expect(stock_location.state_abbr).to eq('DS')
    end

    it 'names a store default country by code' do
      store = create(:store)
      store.update_columns(default_country_id: country.id, default_country_iso_code: nil)

      migrate

      expect(store.reload.default_country_iso_code).to eq('PL')
    end
  end

  describe 'resumability' do
    let!(:address) { create(:address, country: country, state: state) }

    before { clear_iso_columns(address, :country_iso, :state_abbr) }

    it 'reports nothing left to do on a second run' do
      migrate

      expect(described_class.new.call[:addresses]).to eq(0)
    end

    it 'leaves already-migrated rows untouched' do
      migrate
      expect { described_class.new.call }.not_to change { address.reload.country_iso }
    end

    # An interrupted run leaves some rows filled and some empty; the next run
    # has to pick up only what is missing.
    it 'fills only the rows that are still missing a code' do
      other = create(:address, country: country, state: state)
      migrate
      clear_iso_columns(other, :country_iso, :state_abbr)

      expect(described_class.new.call[:addresses]).to eq(2) # country + state for the one row

      expect(other.reload.country_iso).to eq('PL')
    end
  end
end

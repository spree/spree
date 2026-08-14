require 'spec_helper'

# The migrator lives in the rake file (it is a one-release upgrade step, not
# engine infrastructure), so load it the way the task does.
unless defined?(Spree::CountryStateIsoMigrator)
  load Spree::Core::Engine.root.join('lib', 'tasks', 'migrate_country_state_isos.rake')
end

RSpec.describe Spree::CountryStateIsoMigrator do
  subject(:migrate) { described_class.new.call }

  # Countries and states are reference data in 6.0, so the rows this task reads
  # can only come from the legacy tables — which is exactly the state an
  # upgrading store is in. They are seeded by hand, the way the task reads them.
  let(:country_id) { insert_country(iso: 'PL', iso3: 'POL', name: 'Poland') }
  let(:state_id) { insert_state(country_id: country_id, abbr: 'DS', name: 'Dolnoslaskie') }

  def connection
    ActiveRecord::Base.connection
  end

  def insert_country(iso:, iso3:, name:)
    now = connection.quote(Time.current)
    connection.insert(<<~SQL.squish)
      INSERT INTO spree_countries (iso, iso3, iso_name, name, created_at, updated_at)
      VALUES (#{connection.quote(iso)}, #{connection.quote(iso3)},
              #{connection.quote(name.upcase)}, #{connection.quote(name)}, #{now}, #{now})
    SQL
  end

  def insert_state(country_id:, abbr:, name:)
    now = connection.quote(Time.current)
    connection.insert(<<~SQL.squish)
      INSERT INTO spree_states (country_id, abbr, name, created_at, updated_at)
      VALUES (#{country_id}, #{connection.quote(abbr)}, #{connection.quote(name)}, #{now}, #{now})
    SQL
  end

  # Writes the legacy foreign keys and clears the ISO columns, so the row looks
  # the way it did before this release.
  def as_legacy_row(record, country_id: nil, state_id: nil)
    updates = { country_iso: nil }
    updates[:country_id] = country_id if connection.column_exists?(record.class.table_name, :country_id)
    if connection.column_exists?(record.class.table_name, :state_id)
      updates[:state_id] = state_id
      updates[:state_code] = nil
    end

    record.update_columns(updates)
    record.reload
  end

  describe 'addresses' do
    let(:address) { create(:address) }

    it 'names the country and state by code' do
      as_legacy_row(address, country_id: country_id, state_id: state_id)

      migrate

      expect(address.reload.country_iso).to eq('PL')
      expect(address.state_code).to eq('DS')
    end

    it 'leaves an address with no state alone' do
      address.update_columns(state_name: 'Somewhere')
      as_legacy_row(address, country_id: country_id, state_id: nil)

      migrate

      expect(address.reload.country_iso).to eq('PL')
      expect(address.state_code).to be_nil
    end
  end

  describe 'delivery zone members' do
    let(:delivery_zone) { create(:delivery_zone) }

    it 'names a country member by code' do
      member = delivery_zone.members.create!(member_type: 'country', country_iso: 'US')
      as_legacy_row(member, country_id: country_id)

      migrate

      expect(member.reload.country_iso).to eq('PL')
    end

    # A subdivision code is only unique within its country, so a state member
    # has to record both halves or it cannot be resolved on its own.
    it 'gives a state member its country as well' do
      member = delivery_zone.members.create!(member_type: 'state', country_iso: 'US', state_code: 'NY')
      as_legacy_row(member, country_id: nil, state_id: state_id)

      migrate

      expect(member.reload.state_code).to eq('DS')
      expect(member.country_iso).to eq('PL')
    end
  end

  describe 'other consumers' do
    it 'names a market country by code' do
      # DE rather than US — the default store's bootstrap market owns US.
      market = create(:market, store: @default_store, country_isos: ['DE'])
      market_country = market.market_countries.first
      as_legacy_row(market_country, country_id: country_id)

      migrate

      expect(market_country.reload.country_iso).to eq('PL')
    end

    it 'names a stock location country and state by code' do
      stock_location = create(:stock_location)
      as_legacy_row(stock_location, country_id: country_id, state_id: state_id)

      migrate

      expect(stock_location.reload.country_iso).to eq('PL')
      expect(stock_location.state_code).to eq('DS')
    end

    it 'names a store default country by code' do
      store = create(:store)
      # Clears what creation wrote so the backfill is what puts the code back.
      store.update_columns(default_country_id: country_id, default_country_iso_code: nil)

      migrate

      # The store column reflects the legacy foreign key; the market-derived
      # reader is separate and unaffected.
      expect(store.reload.read_attribute(:default_country_iso_code)).to eq('PL')
    end
  end

  # The pre-6.0 seed wrote codes ISO has since retired. Matching compares
  # stored codes verbatim, so a backfilled address carrying the old code would
  # silently stop matching zones written with the successor.
  describe 'retired subdivision codes' do
    let(:za_id) { insert_country(iso: 'ZA', iso3: 'ZAF', name: 'South Africa') }

    it 'rewrites them to the code the gem now uses' do
      gauteng = insert_state(country_id: za_id, abbr: 'GT', name: 'Gauteng')
      address = create(:address)
      as_legacy_row(address, country_id: za_id, state_id: gauteng)

      migrate

      expect(address.reload.state_code).to eq('GP')
    end

    it 'upcases a lower-case legacy code' do
      lower = insert_state(country_id: za_id, abbr: 'wc', name: 'Western Cape')
      address = create(:address)
      as_legacy_row(address, country_id: za_id, state_id: lower)

      migrate

      expect(address.reload.state_code).to eq('WC')
    end
  end

  describe 'resumability' do
    let!(:address) { create(:address) }

    before { as_legacy_row(address, country_id: country_id, state_id: state_id) }

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
      other = create(:address)
      migrate
      as_legacy_row(other, country_id: country_id, state_id: state_id)

      expect(described_class.new.call[:addresses]).to eq(2) # country + state for the one row
      expect(other.reload.country_iso).to eq('PL')
    end
  end
end

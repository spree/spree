require 'spec_helper'
require 'rake'

RSpec.describe 'spree_avalara:upgrade' do
  # The legacy extension's schema no longer exists anywhere, so the spec builds
  # just enough of it to migrate from — column by column, because the table
  # itself may already be there. Core keeps an empty `spree_users` through the
  # Customer rename, so a fresh install has the table without any of the legacy
  # columns; assuming its absence left every example that reads one failing on a
  # newly built database, and passing on a second run only because the previous
  # run had dropped the table on its way out.
  def legacy_user_columns
    { email: :string, vat_id: :string, exemption_number: :string,
      avatax_entity_use_code_id: :integer }
  end

  before(:all) do
    # The upgrader ships inside the task, following core's own upgrade tasks.
    Rake::Task.define_task(:environment)
    load SpreeAvalara::Engine.root.join('lib', 'tasks', 'upgrade.rake')

    connection = ActiveRecord::Base.connection

    @built_legacy_user_table = !connection.table_exists?(:spree_users)
    connection.create_table(:spree_users) if @built_legacy_user_table

    legacy_user_columns.each do |column, type|
      connection.add_column(:spree_users, column, type) unless connection.column_exists?(:spree_users, column)
    end
  end

  # Leaves the schema as it was found: the table goes only if this spec built it,
  # and otherwise just the columns it added come off. Dropping a table the dummy
  # app owns takes it away from every spec that runs afterwards.
  after(:all) do
    connection = ActiveRecord::Base.connection

    if @built_legacy_user_table
      connection.drop_table(:spree_users) if connection.table_exists?(:spree_users)
    else
      legacy_user_columns.each_key do |column|
        connection.remove_column(:spree_users, column) if connection.column_exists?(:spree_users, column)
      end
    end
  end

  let(:upgrader) { SpreeAvalara::Upgrader.new }
  let(:legacy_users) { Class.new(ActiveRecord::Base) { self.table_name = 'spree_users' } }

  before { allow(upgrader).to receive(:say) }

  after { legacy_users.delete_all }

  describe 'the integration' do
    it 'is retyped, keeping the credentials it already had' do
      # Stand in for a legacy row: the class it was typed as no longer exists, so
      # the type is written after the fact.
      legacy = create(:avalara_integration, store: @default_store,
                                            preferred_account_number: '2000336981',
                                            preferred_company_code: 'Spark')
      legacy.update_column(:type, 'Spree::Integrations::Avalara')

      upgrader.call

      retyped = Spree::Integration.find(legacy.id)
      expect(retyped.type).to eq('SpreeAvalara::Integration')
      expect(retyped.preferred_company_code).to eq('Spark')
    end
  end

  describe 'the buyer VAT number' do
    let(:customer) { create(:customer) }

    def migrate(vat_id)
      legacy_users.create!(id: customer.id, email: customer.email, vat_id: vat_id)
      upgrader.call
      customer.tax_identifiers.reload.sole
    end

    it 'becomes a typed registration owned by the customer' do
      identifier = migrate('DE136695976')

      expect(identifier.kind).to eq('eu_vat')
      expect(identifier.value).to eq('DE136695976')
      expect(identifier.validation_status).to be_nil
    end

    it 'reads the regime off the number where it says so' do
      expect(migrate('GB980780684').kind).to eq('gb_vat')
    end

    it 'recognises the Swiss prefix' do
      expect(migrate('CHE-116.281.710').kind).to eq('ch_vat')
    end

    # Northern Ireland files as an EU number.
    it 'recognises Northern Ireland' do
      expect(migrate('XI980780684').kind).to eq('eu_vat')
    end

    it 'falls back to where the customer is when the number does not say' do
      customer.update!(bill_address: create(:address, country_code: 'GB', state_code: nil, zipcode: 'SW1A 1AA'))

      expect(migrate('980780684').kind).to eq('gb_vat')
    end

    it 'runs twice without creating a second registration' do
      legacy_users.create!(id: customer.id, email: customer.email, vat_id: 'DE136695976')

      upgrader.call
      upgrader.call

      expect(customer.tax_identifiers.reload.count).to eq(1)
    end

    # The legacy column was free text, and one bad row must not abort an upgrade.
    it 'leaves a number that does not validate behind, and says so' do
      allow(upgrader).to receive(:say).and_call_original
      legacy_users.create!(id: customer.id, email: customer.email, vat_id: 'DE000000000')

      expect { upgrader.call }.to output(/did not validate/).to_stdout
      expect(customer.tax_identifiers.reload).to be_empty
    end

    it 'skips a legacy user with no matching customer' do
      legacy_users.create!(id: 999_999, email: 'ghost@example.com', vat_id: 'DE136695976')

      expect { upgrader.call }.not_to raise_error
    end
  end

  # Left behind, the Internal engine would read this as real configuration.
  describe 'the synthesized tax rate' do
    it 'is deleted' do
      category = create(:tax_category, store: @default_store)
      rate = create(:tax_rate, store: @default_store, tax_category: category, name: 'AvaTax Official Tax Rate')
      kept = create(:tax_rate, store: @default_store, tax_category: category, name: 'Real VAT')

      upgrader.call

      expect(Spree::TaxRate.where(id: rate.id)).to be_empty
      expect(kept.reload).to be_present
    end
  end

  describe 'pointing markets at Avalara' do
    let!(:market) { @default_store.default_market || create(:market, store: @default_store) }

    it 'claims a market that names no engine, for a store that is connected' do
      create(:avalara_integration, :active, store: @default_store)
      market.update_column(:tax_provider, nil)

      upgrader.call

      expect(market.reload.tax_provider).to eq('SpreeAvalara::TaxProvider')
    end

    # An explicit choice — including an explicit Internal — is someone's decision.
    it 'never rewrites an engine someone chose' do
      create(:avalara_integration, :active, store: @default_store)
      market.update_column(:tax_provider, 'Spree::TaxProvider::Internal')

      upgrader.call

      expect(market.reload.tax_provider).to eq('Spree::TaxProvider::Internal')
    end

    it 'leaves a store with no connected integration alone' do
      market.update_column(:tax_provider, nil)

      upgrader.call

      expect(market.reload.tax_provider).to be_blank
    end
  end

  describe 'a fresh install' do
    it 'runs as a no-op' do
      expect { upgrader.call }.not_to raise_error
    end
  end

  describe 'drop_legacy_schema!' do
    # Dropping a column is real DDL: it commits instead of rolling back with the
    # example's fixture transaction, so the legacy column has to be put back by
    # hand. Without this, every example that migrates a legacy user loses the
    # column it reads — and whether it does depends on the random order.
    after do
      connection = ActiveRecord::Base.connection
      connection.add_column(:spree_users, :vat_id, :string) unless connection.column_exists?(:spree_users, :vat_id)
      connection.schema_cache.clear! if connection.respond_to?(:schema_cache)
    end

    it 'drops the migrated columns and keeps the exemption source' do
      upgrader.drop_legacy_schema!

      connection = ActiveRecord::Base.connection
      expect(connection.column_exists?(:spree_users, :vat_id)).to be(false)
      expect(connection.column_exists?(:spree_users, :exemption_number)).to be(true)
      expect(connection.column_exists?(:spree_users, :avatax_entity_use_code_id)).to be(true)
    end
  end
end

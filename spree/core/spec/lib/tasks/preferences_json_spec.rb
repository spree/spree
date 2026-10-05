require 'spec_helper'
require 'rake'

describe 'preferences stored as JSON' do
  before(:all) do
    Rake::Task.define_task(:environment)
    load Spree::Core::Engine.root.join('lib', 'tasks', 'preferences_json.rake')
  end

  let(:connection) { ActiveRecord::Base.connection }
  let(:conversion) { Spree::Preferences::JsonConversion.new(connection) }

  describe Spree::Preferences::JsonConversion do
    let(:table_name) { 'spree_legacy_preference_fixtures' }
    let(:quoted_table) { connection.quote_table_name(table_name) }

    # The real tables are converted by the migration, so the conversion is
    # exercised against a synthetic table in the pre-6.0 shape: YAML text, plus
    # the JSON column the migration writes into. Built once, outside the
    # example's transaction, because MySQL commits any open transaction when a
    # table is created.
    before(:all) do
      ActiveRecord::Base.connection.create_table 'spree_legacy_preference_fixtures', force: true do |t|
        t.string :type
        t.text :preferences
        t.text :secret_preferences
        t.json :preferences_json
      end
    end

    after(:all) { ActiveRecord::Base.connection.drop_table 'spree_legacy_preference_fixtures', if_exists: true }

    def insert_row(preferences, type: nil)
      connection.exec_insert(
        "INSERT INTO #{quoted_table} (type, preferences) VALUES (#{connection.quote(type)}, #{connection.quote(preferences)})"
      )
      connection.select_values("SELECT id FROM #{quoted_table} ORDER BY id DESC").first
    end

    def column(id, name)
      value = connection.select_value("SELECT #{connection.quote_column_name(name)} FROM #{quoted_table} WHERE id = #{connection.quote(id)}")
      value.is_a?(String) ? JSON.parse(value) : value
    end

    def convert
      conversion.convert_table(table_name, target: 'preferences_json')
    end

    it 'writes YAML preferences as JSON with string keys and exact decimals' do
      id = insert_row(YAML.dump({ amount: BigDecimal('9.99'), currency: 'USD', ids: [1, 2], enabled: true, starts_on: Date.new(2026, 1, 1) }))

      convert

      expect(column(id, 'preferences_json')).to eq(
        'amount' => '9.99', 'currency' => 'USD', 'ids' => [1, 2], 'enabled' => true, 'starts_on' => '2026-01-01'
      )
    end

    it 'reads a hash dumped with indifferent access' do
      id = insert_row(YAML.dump(ActiveSupport::HashWithIndifferentAccess.new(code: 'x')))

      convert

      expect(column(id, 'preferences_json')).to eq('code' => 'x')
    end

    it 'moves secrets of a resolvable class into secret_preferences' do
      id = insert_row(YAML.dump({ dummy_key: 'pk_1', dummy_secret_key: 'sk_live_1' }), type: 'Spree::Gateway::Bogus')

      convert

      expect(column(id, 'preferences_json')).to eq('dummy_key' => 'pk_1')
      expect(column(id, 'secret_preferences')).to eq('dummy_secret_key' => 'sk_live_1')
    end

    it 'leaves secrets in place when the class cannot be loaded' do
      id = insert_row(YAML.dump({ api_key: 'sk_live_1' }), type: 'Spree::Gateway::Uninstalled')

      convert

      expect(column(id, 'preferences_json')).to eq('api_key' => 'sk_live_1')
      expect(column(id, 'secret_preferences')).to be_nil
    end

    it 'turns tiers keyed by threshold into a list, lowest threshold first' do
      id = insert_row(YAML.dump({ base_percent: BigDecimal('5'), tiers: { 200.0 => 20.0, 100.0 => 15.0 } }), type: 'Spree::Calculator::TieredPercent')

      convert

      expect(column(id, 'preferences_json')['tiers']).to eq(
        [{ 'threshold' => '100.0', 'value' => '15.0' }, { 'threshold' => '200.0', 'value' => '20.0' }]
      )
    end

    it "converts an application's subclass of a tiered calculator too" do
      stub_const('MyApp::LoyaltyTiers', Class.new(Spree::Calculator::TieredFlatRate))
      id = insert_row(YAML.dump({ tiers: { 50.0 => 5.0 } }), type: 'MyApp::LoyaltyTiers')

      convert

      expect(column(id, 'preferences_json')['tiers']).to eq([{ 'threshold' => '50.0', 'value' => '5.0' }])
    end

    it 'converts only tables a model storing Spree preferences reads' do
      expect(conversion.preference_tables).to include('spree_payment_methods', 'spree_stores')
      expect(conversion.preference_tables).not_to include(table_name)
    end

    it 'stops on a row it cannot read, naming the table and row' do
      id = insert_row("--- !ruby/hash-with-ivars:ActionController::Parameters\nelements: {}\n")

      expect { convert }.to raise_error(Spree::Preferences::JsonConversion::UnreadableRowError, /#{table_name} row #{id}/)
    end

    context 'when the column is already JSON but holds a YAML string' do
      it 'rewrites the row in place' do
        id = insert_row(nil)
        connection.exec_update("UPDATE #{quoted_table} SET preferences_json = #{connection.quote(YAML.dump({ min: 3 }).to_json)} WHERE id = #{id}")

        conversion.convert_table(table_name, source: 'preferences_json', target: 'preferences_json')

        expect(column(id, 'preferences_json')).to eq('min' => 3)
      end

      it 'leaves rows that are already JSON objects alone' do
        id = insert_row(nil)
        connection.exec_update("UPDATE #{quoted_table} SET preferences_json = #{connection.quote({ min: 3 }.to_json)} WHERE id = #{id}")

        expect(conversion.convert_table(table_name, source: 'preferences_json', target: 'preferences_json')).to eq(0)
      end

      it 'still reshapes tiers left as a hash, as when the calculator was not loaded during the migration' do
        id = insert_row(nil, type: 'Spree::Calculator::TieredPercent')
        connection.exec_update("UPDATE #{quoted_table} SET preferences_json = #{connection.quote({ tiers: { '100.0' => '15.0' } }.to_json)} WHERE id = #{id}")

        conversion.convert_table(table_name, source: 'preferences_json', target: 'preferences_json')

        expect(column(id, 'preferences_json')['tiers']).to eq([{ 'threshold' => '100.0', 'value' => '15.0' }])
      end
    end
  end

  describe 'spree:upgrade:preferences_json' do
    let(:task) { Rake::Task['spree:upgrade:preferences_json'] }
    let(:payment_method) { create(:credit_card_payment_method) }

    after { task.reenable }

    # A table whose model the migration did not load — an extension installed
    # after the upgrade — still has the pre-6.0 text column.
    context 'when a preferences column is still text' do
      let(:table_name) { 'spree_late_extension_settings' }

      before do
        connection.create_table(table_name, force: true) { |t| t.text :preferences }
        stub_const('LateExtensionSetting', Class.new(Spree::Base) { self.table_name = 'spree_late_extension_settings' })
        connection.exec_insert("INSERT INTO #{table_name} (preferences) VALUES (#{connection.quote(YAML.dump({ limit: 5 }))})")
      end

      after { connection.drop_table table_name, if_exists: true }

      it 'replaces it with a JSON column and converts its rows' do
        expect { task.invoke }.to output(/#{table_name}: 1 rows converted/).to_stdout

        expect(connection.columns(table_name).find { |column| column.name == 'preferences' }.type).not_to eq(:text)
        value = connection.select_value("SELECT preferences FROM #{table_name}")
        expect(value.is_a?(String) ? JSON.parse(value) : value).to eq('limit' => 5)
      end
    end

    # A secret left in `preferences` is what a class unloaded at migration time
    # leaves behind.
    it 'moves secrets left in preferences without treating it as a change to them' do
      connection.exec_update(
        "UPDATE spree_payment_methods SET preferences = #{connection.quote({ dummy_key: 'pk_1', dummy_secret_key: 'sk_left' }.to_json)}, " \
        "secret_preferences = NULL WHERE id = #{payment_method.id}"
      )

      expect { task.invoke }.to output(/moved secrets out of preferences for 1 rows/).to_stdout

      reloaded = Spree::PaymentMethod.find(payment_method.id)
      expect(reloaded.preferences).not_to have_key('dummy_secret_key')
      expect(reloaded.preferred_dummy_secret_key).to eq('sk_left')
    end
  end

  describe 'a row whose class is no longer installed' do
    let(:task) { Rake::Task['spree:upgrade:encrypt_secret_preferences'] }
    let!(:payment_method) { create(:credit_card_payment_method) }
    let!(:uninstalled) { create(:credit_card_payment_method) }

    after do
      task.reenable
      connection.exec_delete("DELETE FROM spree_payment_methods WHERE id = #{uninstalled.id}")
    end

    it 'is skipped and reported, and the other rows are still processed' do
      connection.exec_update("UPDATE spree_payment_methods SET type = 'SpreeRemovedGem::Gateway' WHERE id = #{uninstalled.id}")
      connection.exec_update(
        "UPDATE spree_payment_methods SET secret_preferences = #{connection.quote({ dummy_secret_key: 'sk_plain' }.to_json)} WHERE id = #{payment_method.id}"
      )

      expect { task.invoke }.to output(/skipped rows of SpreeRemovedGem::Gateway/).to_stdout

      raw = connection.select_value("SELECT secret_preferences FROM spree_payment_methods WHERE id = #{payment_method.id}")
      expect(raw).not_to include('sk_plain')
    end
  end

  describe 'spree:upgrade:encrypt_secret_preferences' do
    let(:task) { Rake::Task['spree:upgrade:encrypt_secret_preferences'] }
    let(:payment_method) { create(:credit_card_payment_method) }

    after { task.reenable }

    it 'encrypts a secret the migration moved in plain text, which stays readable' do
      connection.exec_update(
        "UPDATE spree_payment_methods SET secret_preferences = #{connection.quote({ dummy_secret_key: 'sk_plain' }.to_json)} WHERE id = #{payment_method.id}"
      )
      expect(Spree::PaymentMethod.find(payment_method.id).preferred_dummy_secret_key).to eq('sk_plain')

      expect { task.invoke }.to output(/encrypted secrets/).to_stdout

      raw = connection.select_value("SELECT secret_preferences FROM spree_payment_methods WHERE id = #{payment_method.id}")
      expect(raw).not_to include('sk_plain')
      expect(Spree::PaymentMethod.find(payment_method.id).preferred_dummy_secret_key).to eq('sk_plain')
    end
  end
end

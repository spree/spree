require 'spec_helper'

describe Spree::Preferences::Preferable, type: :model do
  before :all do
    ActiveRecord::Migration.suppress_messages do
      ActiveRecord::Migration.create_table(:preferable_spec_records, force: true) { |t| t.json :preferences }
    end

    class A < Spree::Base
      self.table_name = 'preferable_spec_records'

      preference :color, :string, default: 'green', deprecated: 'Please use colour instead'
    end

    class B < A
      preference :flavor, :string
    end
  end

  after :all do
    ActiveRecord::Migration.suppress_messages { ActiveRecord::Migration.drop_table(:preferable_spec_records) }
  end

  before do
    @a = A.new
    @b = B.new
  end

  describe 'preference definitions' do
    it 'parent should not see child definitions' do
      expect(@a.has_preference?(:color)).to be true
      expect(@a.has_preference?(:flavor)).not_to be true
    end

    it 'child should have parent and own definitions' do
      expect(@b.has_preference?(:color)).to be true
      expect(@b.has_preference?(:flavor)).to be true
    end

    it 'instances have defaults' do
      expect(@a.preferred_color).to eq 'green'
      expect(@b.preferred_color).to eq 'green'
      expect(@b.preferred_flavor).to be_nil
    end

    it 'can be asked if it has a preference definition' do
      expect(@a.has_preference?(:color)).to be true
      expect(@a.has_preference?(:bad)).to be false
    end

    it 'can be asked and raises' do
      expect do
        @a.has_preference! :flavor
      end.to raise_error(NoMethodError, 'flavor preference not defined')
    end

    it 'has a type' do
      expect(@a.preference_type(:color)).to eq :string
    end

    it 'has a default' do
      expect(@a.preference_default(:color)).to eq 'green'
    end

    it 'can have a deprecation message' do
      expect(@a.preference_deprecated(:color)).to eq 'Please use colour instead'
    end

    it 'raises if not defined' do
      expect do
        @a.get_preference :flavor
      end.to raise_error(NoMethodError, 'flavor preference not defined')
    end
  end

  describe 'preference access' do
    it 'handles ghost methods for preferences' do
      @a.preferred_color = 'blue'
      expect(@a.preferred_color).to eq 'blue'
    end

    it 'parent and child instances have their own prefs' do
      @a.preferred_color = 'red'
      @b.preferred_color = 'blue'

      expect(@a.preferred_color).to eq 'red'
      expect(@b.preferred_color).to eq 'blue'
    end

    it 'raises when preference not defined' do
      expect do
        @a.set_preference(:bad, :bone)
      end.to raise_exception(NoMethodError, 'bad preference not defined')
    end

    it 'builds a hash of preferences' do
      @b.preferred_flavor = :strawberry
      expect(@b.preferences[:flavor]).to eq 'strawberry'
      expect(@b.preferences[:color]).to eq 'green' # default from A
    end

    it 'builds a hash of preference defaults' do
      expect(@b.default_preferences).to eq(flavor: nil,
                                           color: 'green')
    end

    context 'converts integer preferences to integer values' do
      before do
        A.preference :is_integer, :integer
      end

      it 'with strings' do
        @a.set_preference(:is_integer, '3')
        expect(@a.preferences[:is_integer]).to eq(3)

        @a.set_preference(:is_integer, '')
        expect(@a.preferences[:is_integer]).to eq(0)
      end
    end

    context 'converts nullable integer preferences' do
      before do
        A.preference :nullable_integer, :integer, nullable: true
      end

      it 'stores nil when set to empty string' do
        @a.set_preference(:nullable_integer, '')
        expect(@a.preferences[:nullable_integer]).to be_nil
      end

      it 'stores nil when set to nil' do
        @a.set_preference(:nullable_integer, nil)
        expect(@a.preferences[:nullable_integer]).to be_nil
      end

      it 'converts string to integer when present' do
        @a.set_preference(:nullable_integer, '42')
        expect(@a.preferences[:nullable_integer]).to eq(42)
      end

      it 'preserves integer values' do
        @a.set_preference(:nullable_integer, 100)
        expect(@a.preferences[:nullable_integer]).to eq(100)
      end
    end

    context 'converts decimal preferences to BigDecimal values' do
      before do
        A.preference :if_decimal, :decimal
      end

      it 'returns a BigDecimal, stored as its exact string' do
        @a.set_preference(:if_decimal, 3.3)
        expect(@a.get_preference(:if_decimal)).to eq(BigDecimal('3.3'))
        expect(@a.preferences[:if_decimal]).to eq('3.3')
      end

      it 'with strings' do
        @a.set_preference(:if_decimal, '3.3')
        expect(@a.get_preference(:if_decimal)).to eq(3.3)

        @a.set_preference(:if_decimal, '')
        expect(@a.get_preference(:if_decimal)).to eq(0.0)
      end

      it 'refuses text it would otherwise misread' do
        expect { @a.set_preference(:if_decimal, '1,599.99') }.to raise_error(Spree::Money::InvalidFormat)
      end

      it 'stores and returns a decimal default as a BigDecimal, so setting the same amount is not a change' do
        A.preference :decimal_with_default, :decimal, default: 0.0
        record = A.create!
        loaded = A.find(record.id)

        expect(loaded.preferences[:decimal_with_default]).to eq('0.0')
        expect(loaded.preferred_decimal_with_default).to be_a(BigDecimal)

        loaded.preferred_decimal_with_default = 0
        expect(loaded).not_to be_changed
      end

      it 'treats a money preference the same way' do
        A.preference :money_with_default, :money, default: 0
        loaded = A.find(A.create!.id)

        expect(loaded.preferred_money_with_default).to be_a(BigDecimal)

        loaded.preferred_money_with_default = '0'
        expect(loaded).not_to be_changed
      end
    end

    context 'converts nullable decimal preferences' do
      before do
        A.preference :nullable_decimal, :decimal, nullable: true
      end

      it 'stores nil when set to empty string' do
        @a.set_preference(:nullable_decimal, '')
        expect(@a.preferences[:nullable_decimal]).to be_nil
      end

      it 'stores nil when set to nil' do
        @a.set_preference(:nullable_decimal, nil)
        expect(@a.preferences[:nullable_decimal]).to be_nil
      end

      it 'converts string to BigDecimal when present' do
        @a.set_preference(:nullable_decimal, '3.14')
        expect(@a.get_preference(:nullable_decimal)).to eq(BigDecimal('3.14'))
        expect(@a.get_preference(:nullable_decimal).class).to eq(BigDecimal)
      end

      it 'preserves decimal values' do
        @a.set_preference(:nullable_decimal, 9.99)
        expect(@a.get_preference(:nullable_decimal)).to eq(BigDecimal('9.99'))
      end
    end

    context 'converts boolean preferences to boolean values' do
      before do
        A.preference :is_boolean, :boolean, default: true
      end

      it 'with strings' do
        @a.set_preference(:is_boolean, '0')
        expect(@a.preferences[:is_boolean]).to be false
        @a.set_preference(:is_boolean, 'f')
        expect(@a.preferences[:is_boolean]).to be false
        @a.set_preference(:is_boolean, 't')
        expect(@a.preferences[:is_boolean]).to be true
      end

      it 'with integers' do
        @a.set_preference(:is_boolean, 0)
        expect(@a.preferences[:is_boolean]).to be false
        @a.set_preference(:is_boolean, 1)
        expect(@a.preferences[:is_boolean]).to be true
      end

      it 'with an empty string' do
        @a.set_preference(:is_boolean, '')
        expect(@a.preferences[:is_boolean]).to be false
      end

      it 'with an empty hash' do
        @a.set_preference(:is_boolean, [])
        expect(@a.preferences[:is_boolean]).to be false
      end
    end

    context 'converts nullable boolean preferences' do
      before do
        A.preference :nullable_boolean, :boolean, default: nil, nullable: true
      end

      it 'stores nil when set to nil' do
        @a.set_preference(:nullable_boolean, nil)
        expect(@a.preferences[:nullable_boolean]).to be_nil
      end

      it 'stores nil when set to an empty string' do
        @a.set_preference(:nullable_boolean, '')
        expect(@a.preferences[:nullable_boolean]).to be_nil
      end

      it 'preserves an explicit false (does not collapse it to nil)' do
        @a.set_preference(:nullable_boolean, false)
        expect(@a.preferences[:nullable_boolean]).to be false
        @a.set_preference(:nullable_boolean, 'f')
        expect(@a.preferences[:nullable_boolean]).to be false
      end

      it 'preserves an explicit true' do
        @a.set_preference(:nullable_boolean, true)
        expect(@a.preferences[:nullable_boolean]).to be true
      end
    end

    context 'converts array preferences to array values' do
      before do
        A.preference :is_array, :array, default: []
      end

      it 'with arrays' do
        @a.set_preference(:is_array, [])
        expect(@a.preferences[:is_array]).to be_is_a(Array)
      end

      it 'with string' do
        @a.set_preference(:is_array, 'string')
        expect(@a.preferences[:is_array]).to be_is_a(Array)
      end

      it 'with hash' do
        @a.set_preference(:is_array, {})
        expect(@a.preferences[:is_array]).to be_is_a(Array)
      end
    end

    context 'converts hash preferences to hash values' do
      before do
        A.preference :is_hash, :hash, default: {}
      end

      it 'with hash' do
        @a.set_preference(:is_hash, {})
        expect(@a.preferences[:is_hash]).to be_is_a(Hash)
      end

      it 'with hash and keys are integers, which JSON keeps as strings' do
        @a.set_preference(:is_hash, 1 => 2, 3 => 4)
        expect(@a.preferences[:is_hash]).to eql('1' => 2, '3' => 4)
      end

      it 'with string' do
        @a.set_preference(:is_hash, '{"0"=>{"answer"=>"1", "value"=>"No"}}')
        expect(@a.preferences[:is_hash]).to be_is_a(Hash)
      end

      it 'with boolean' do
        @a.set_preference(:is_hash, false)
        expect(@a.preferences[:is_hash]).to be_is_a(Hash)
        @a.set_preference(:is_hash, true)
        expect(@a.preferences[:is_hash]).to be_is_a(Hash)
      end

      it 'with simple array' do
        @a.set_preference(:is_hash, ['key', 'value', 'another key', 'another value'])
        expect(@a.preferences[:is_hash]).to be_is_a(Hash)
        expect(@a.preferences[:is_hash]['key']).to eq('value')
        expect(@a.preferences[:is_hash]['another key']).to eq('another value')
      end

      it 'with a nested array' do
        @a.set_preference(:is_hash, [['key', 'value'], ['another key', 'another value']])
        expect(@a.preferences[:is_hash]).to be_is_a(Hash)
        expect(@a.preferences[:is_hash]['key']).to eq('value')
        expect(@a.preferences[:is_hash]['another key']).to eq('another value')
      end

      it 'with single array' do
        expect { @a.set_preference(:is_hash, ['key']) }.to raise_error(ArgumentError)
      end

      it 'with permitted strong parameters' do
        parameters = ActionController::Parameters.new(amounts: { 'EUR' => '15.0' }).permit(amounts: {})

        @a.set_preference(:is_hash, parameters[:amounts])

        expect(@a.preferences[:is_hash]).to eq('EUR' => '15.0')
        expect(@a.preferences[:is_hash]).to be_is_a(Hash)
      end

      it 'with unpermitted strong parameters' do
        parameters = ActionController::Parameters.new('EUR' => '15.0')

        expect { @a.set_preference(:is_hash, parameters) }.to raise_error(ActionController::UnfilteredParameters)
      end
    end

    # Deliberately not coerced to a Date: a date's meaning depends on the
    # store's timezone, which the coercion has no access to, so the reader
    # applies the zone instead. The type exists so the admin form renders a
    # picker.
    context 'keeps date preferences as plain yyyy-mm-dd strings' do
      before do
        A.preference :effective_from, :date, default: nil
      end

      it 'keeps a date string as written' do
        @a.set_preference(:effective_from, '2026-01-01')
        expect(@a.preferences[:effective_from]).to eq('2026-01-01')
      end

      it 'keeps a full timestamp, so an existing stored value still reads back' do
        @a.set_preference(:effective_from, '2026-01-01T09:00:00Z')
        expect(@a.preferences[:effective_from]).to eq('2026-01-01T09:00:00Z')
      end

      it 'formats a Date object rather than storing the object itself' do
        @a.set_preference(:effective_from, Date.new(2026, 1, 1))
        expect(@a.preferences[:effective_from]).to eq('2026-01-01')
      end

      it 'treats a blank value as unset' do
        @a.set_preference(:effective_from, '')
        expect(@a.preferences[:effective_from]).to be_nil
      end
    end

    context 'converts any preferences to any values' do
      before do
        A.preference :product_ids, :any, default: []
        A.preference :product_attributes, :any, default: {}
        @a = A.new
      end

      it 'with array' do
        expect(@a.preferences[:product_ids]).to eq([])
        @a.set_preference(:product_ids, [1, 2])
        expect(@a.preferences[:product_ids]).to eq([1, 2])
      end

      it 'with hash' do
        expect(@a.preferences[:product_attributes]).to eq({})
        @a.set_preference(:product_attributes, id: 1, name: 2)
        expect(@a.preferences[:product_attributes]).to eq('id' => 1, 'name' => 2)
      end
    end
  end

  describe 'typed declarations' do
    let(:preferable_class) do
      Class.new(Spree::Base) do
        self.table_name = 'preferable_spec_records'

        def self.name
          'TypedPreferable'
        end

        preference :channel_ids, :array, of: :id, model: 'Spree::Channel', default: [],
                                         scope: ->(_record) { Spree::Store.default.channels }
        preference :quantities, :array, of: :integer, default: []
        preference :amounts, :hash, keys: :currency, values: :money, default: {}
        preference :tiers, :array, of: :object, properties: { threshold: :money, value: :decimal }, default: []
        preference :flavor, :string, default: 'vanilla'
        exposes_preferences :flavor
      end
    end
    let(:record) { preferable_class.new }
    let(:channel) { create(:channel) }

    it 'decodes prefixed ids to the raw primary keys it stores' do
      record.set_preference(:channel_ids, [channel.prefixed_id])
      expect(record.preferences[:channel_ids]).to eq([channel.id.to_s])
    end

    it 'accepts a comma-separated list' do
      record.set_preference(:channel_ids, "#{channel.prefixed_id}, #{channel.id}")
      expect(record.preferences[:channel_ids]).to eq([channel.id.to_s, channel.id.to_s])
    end

    it 'refuses an id carrying another model\'s prefix, even when it decodes to an existing row' do
      market_id = "mkt_#{Spree::PrefixedId::SQIDS.encode([channel.id])}"
      expect { record.set_preference(:channel_ids, [market_id]) }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it 'refuses an id outside the declared scope' do
      other_channel = create(:channel, store: create(:store))
      expect { record.set_preference(:channel_ids, [other_channel.prefixed_id]) }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it 'casts list items to their declared type' do
      record.set_preference(:quantities, ['1', 2])
      expect(record.preferences[:quantities]).to eq([1, 2])
    end

    it 'keeps an item that does not cast, for validation to name' do
      record.set_preference(:quantities, ['many'])
      expect(record.preferences[:quantities]).to eq(['many'])
    end

    it 'stores hash values in their declared type, with currency keys upcased' do
      record.set_preference(:amounts, 'eur' => 15, 'USD' => '9.99')
      expect(record.preferences[:amounts]).to eq('EUR' => '15.0', 'USD' => '9.99')
    end

    it 'keeps only the declared properties of each object, typed' do
      record.set_preference(:tiers, [{ threshold: 100, value: '10', note: 'dropped' }])
      expect(record.preferences[:tiers]).to eq([{ 'threshold' => '100.0', 'value' => '10.0' }])
    end

    it 'exposes a preference under its plain name' do
      expect(record.flavor).to eq('vanilla')
      record.flavor = 'mint'
      expect(record.preferred_flavor).to eq('mint')
    end

    it 'refuses to expose a name that is not a preference or is already a method' do
      expect { preferable_class.exposes_preferences :not_declared }.to raise_error(ArgumentError, /no preference/)
      expect { preferable_class.exposes_preferences :flavor }.to raise_error(ArgumentError, /a method of that name exists/)
    end

    it 'raises for an option that does not fit the type' do
      expect { preferable_class.preference :wrong_of, :string, of: :integer }.to raise_error(ArgumentError, /`of:` applies to an :array/)
      expect { preferable_class.preference :id_without_model, :array, of: :id }.to raise_error(ArgumentError, /needs `model:`/)
      expect { preferable_class.preference :unknown_item, :array, of: :thing }.to raise_error(ArgumentError, /Unknown item type/)
    end

    describe '#assign_preferences' do
      it 'writes a payload that matches the schema' do
        record.assign_preferences('quantities' => [1, 2], 'channel_ids' => [channel.prefixed_id])

        expect(record.preferred_quantities).to eq([1, 2])
        expect(record.preferences[:channel_ids]).to eq([channel.id.to_s])
      end

      it 'refuses the whole payload, naming each failing value, when any value does not match' do
        expect { record.assign_preferences('flavor' => 'mint', 'quantities' => ['many'], 'colour' => 'red') }.to raise_error(
          Spree::Preferences::InvalidPreferences
        ) { |error| expect(error.failures.pluck(:pointer)).to contain_exactly('/preferences/quantities/0', '/preferences/colour') }
        expect(record.preferred_flavor).to eq('vanilla')
      end

      it 'refuses an id of another model by its prefix' do
        expect { record.assign_preferences('channel_ids' => ["mkt_#{Spree::PrefixedId::SQIDS.encode([channel.id])}"]) }
          .to raise_error(Spree::Preferences::InvalidPreferences, %r{/preferences/channel_ids/0})
      end

      it 'refuses an id outside the declared scope' do
        other_channel = create(:channel, store: create(:store))

        expect { record.assign_preferences('channel_ids' => [other_channel.prefixed_id]) }
          .to raise_error(Spree::Preferences::InvalidPreferences, %r{/preferences/channel_ids})
      end
    end

    it 'warns about a declaration that does not state its full type' do
      expect(Spree::Deprecation).to receive(:warn).with(/needs `of:`/)
      preferable_class.preference :untyped_list, :array, default: []
    end

    it 'accepts the legacy `in:` option with a warning' do
      expect(Spree::Deprecation).to receive(:warn).with(/Use `choices:` instead/)
      preferable_class.preference :legacy_choice, :string, in: %w[a b]
      expect(preferable_class.preference_definitions[:legacy_choice][:choices]).to eq(%w[a b])
    end
  end

  describe 'persisted preferables' do
    before(:all) do
      class CreatePrefTest < ActiveRecord::Migration[4.2]
        def self.up
          create_table :pref_tests do |t|
            t.string :col
            t.json :preferences
          end
        end

        def self.down
          drop_table :pref_tests
        end
      end

      @migration_verbosity = ActiveRecord::Migration.verbose
      ActiveRecord::Migration.verbose = false
      CreatePrefTest.migrate(:up)

      class PrefTest < Spree::Base
        preference :pref_test_pref, :string, default: 'abc'
        preference :pref_test_any, :any, default: []
        preference :pref_test_decimal, :decimal, default: 0
        preference :pref_test_datetime, :datetime
      end
    end

    after(:all) do
      CreatePrefTest.migrate(:down)
      ActiveRecord::Migration.verbose = @migration_verbosity
    end

    before do
      # load PrefTest table
      PrefTest.first
      @pt = PrefTest.create
    end

    describe 'pending preferences for new activerecord objects' do
      it 'saves preferences after record is saved' do
        pr = PrefTest.new
        pr.set_preference(:pref_test_pref, 'XXX')
        expect(pr.get_preference(:pref_test_pref)).to eq('XXX')
        pr.save!
        expect(pr.get_preference(:pref_test_pref)).to eq('XXX')
      end

      it 'saves preferences for serialized object' do
        pr = PrefTest.new
        pr.set_preference(:pref_test_any, [1, 2])
        expect(pr.get_preference(:pref_test_any)).to eq([1, 2])
        pr.save!
        expect(pr.get_preference(:pref_test_any)).to eq([1, 2])
      end
    end

    it 'clear preferences when record is deleted' do
      @pt.save!
      @pt.preferred_pref_test_pref = 'lmn'
      @pt.save!
      @pt.destroy
      @pt1 = PrefTest.new(col: 'aaaa')
      @pt1.id = @pt.id
      @pt1.save!
      expect(@pt1.get_preference(:pref_test_pref)).to eq('abc')
    end

    describe 'JSON storage' do
      it 'restores a decimal exactly after a round trip' do
        @pt.update!(preferred_pref_test_decimal: '19.99')

        expect(PrefTest.find(@pt.id).preferred_pref_test_decimal).to eq(BigDecimal('19.99'))
      end

      it 'restores a time after a round trip' do
        time = Time.zone.parse('2026-03-01 09:30:00')
        @pt.update!(preferred_pref_test_datetime: time)
        reloaded = PrefTest.find(@pt.id)

        expect(reloaded.preferred_pref_test_datetime).to eq(time)
        reloaded.preferred_pref_test_datetime = time
        expect(reloaded.preferred_pref_test_datetime_changed?).to be(false)
      end

      it 'reads stored keys with indifferent access' do
        @pt.update!(preferred_pref_test_pref: 'xyz')
        reloaded = PrefTest.find(@pt.id)

        expect(reloaded.preferences[:pref_test_pref]).to eq('xyz')
        expect(reloaded.preferences['pref_test_pref']).to eq('xyz')
      end

      it 'does not mark a loaded record as changed' do
        expect(PrefTest.find(@pt.id).changed?).to be(false)
      end

      it 'does not report a change when a decimal is set to the value it holds' do
        @pt.update!(preferred_pref_test_decimal: '19.99')
        reloaded = PrefTest.find(@pt.id)
        reloaded.preferred_pref_test_decimal = BigDecimal('19.99')

        expect(reloaded.preferred_pref_test_decimal_changed?).to be(false)
      end
    end

    describe 'preference change tracking methods' do
      it 'tracks changes to preferences' do
        @pt.preferred_pref_test_pref = 'xyz'
        expect(@pt.preferred_pref_test_pref_changed?).to be true
        expect(@pt.preferred_pref_test_pref_change).to eq(['abc', 'xyz'])
        expect(@pt.preferred_pref_test_pref_was).to eq('abc')
      end

      it 'tracks previous changes after save' do
        @pt.preferred_pref_test_pref = 'xyz'
        @pt.save!

        expect(@pt.saved_change_to_preferred_pref_test_pref?).to be true
        expect(@pt.saved_change_to_preferred_pref_test_pref).to eq(['abc', 'xyz'])
        expect(@pt.preferred_pref_test_pref_before_last_save).to eq('abc')
      end

      it 'reports no changes when preference is set to same value' do
        @pt.preferred_pref_test_pref = 'abc'
        expect(@pt.preferred_pref_test_pref_changed?).to be false
        expect(@pt.preferred_pref_test_pref_change).to be_nil
      end

      it 'tracks changes to array preferences' do
        @pt.preferred_pref_test_any = [1, 2, 3]
        expect(@pt.preferred_pref_test_any_changed?).to be true
        expect(@pt.preferred_pref_test_any_change).to eq([[], [1, 2, 3]])
        expect(@pt.preferred_pref_test_any_was).to eq([])
      end
    end
  end
end

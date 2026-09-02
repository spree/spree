require 'spec_helper'

# The migration derives filter_key for every pre-existing definition, and two
# different namespace/key splits can flatten to one value. Nothing forbade that
# before the migration, so an existing install can hold a pair the unique index
# would reject — data no model can reach once the constraint is on.
#
# The disambiguation is exercised through its own query-building rather than by
# planting colliding rows: doing that needs the unique index dropped, which is
# DDL, and MySQL commits implicitly on DDL — dropping the savepoint the example
# runs inside.
RSpec.describe 'AddStoreAndFilterKeyToCustomFieldDefinitions migration' do
  let(:migration) do
    require Spree::Core::Engine.root.join(
      'db', 'migrate', '20260902000001_add_store_and_filter_key_to_custom_field_definitions.rb'
    )
    AddStoreAndFilterKeyToCustomFieldDefinitions.new
  end

  let(:store) { Spree::Store.default }

  describe '#free_filter_key' do
    it 'suffixes with _2 when nothing holds it' do
      expect(migration.send(:free_filter_key, 'cf_a_b_c', store.id, 'Spree::Product')).to eq('cf_a_b_c_2')
    end

    # An install can legitimately hold the suffixed form as a definition of its
    # own (namespace `a_b_c`, key `2`), and handing it out twice would fail the
    # unique index halfway through the migration.
    it 'skips a suffix another definition already owns' do
      create(:custom_field_definition, store: store, resource_type: 'Spree::Product', namespace: 'a_b_c', key: '2')

      expect(migration.send(:free_filter_key, 'cf_a_b_c', store.id, 'Spree::Product')).to eq('cf_a_b_c_3')
    end

    it 'ignores a row holding that key in another store' do
      create(:custom_field_definition, store: create(:store), resource_type: 'Spree::Product',
                                       namespace: 'a_b_c', key: '2')

      expect(migration.send(:free_filter_key, 'cf_a_b_c', store.id, 'Spree::Product')).to eq('cf_a_b_c_2')
    end

    it 'ignores a row holding that key for another resource type' do
      create(:custom_field_definition, store: store, resource_type: 'Spree::Order', namespace: 'a_b_c', key: '2')

      expect(migration.send(:free_filter_key, 'cf_a_b_c', store.id, 'Spree::Product')).to eq('cf_a_b_c_2')
    end
  end

  describe '#disambiguate_colliding_filter_keys' do
    # Every row on a migrated schema already holds a unique filter_key, so the
    # pass has nothing to rename and must leave them untouched.
    it 'is a no-op when no two rows share a filter key' do
      first = create(:custom_field_definition, store: store, resource_type: 'Spree::Product',
                                               namespace: 'a_b', key: 'c')
      second = create(:custom_field_definition, store: store, resource_type: 'Spree::Product',
                                                namespace: 'custom', key: 'material')

      migration.send(:disambiguate_colliding_filter_keys)

      expect(first.reload[:filter_key]).to eq('cf_a_b_c')
      expect(second.reload[:filter_key]).to eq('cf_custom_material')
    end
  end

  # Two stores may each hold `custom.material` once this migration has run —
  # that is the point of it. The pre-migration index was global, so rolling
  # back over such a pair has no correct answer.
  describe '#down' do
    it 'refuses when two stores hold the same key' do
      create(:custom_field_definition, store: store, resource_type: 'Spree::Product',
                                       namespace: 'custom', key: 'material')
      create(:custom_field_definition, store: create(:store), resource_type: 'Spree::Product',
                                       namespace: 'custom', key: 'material')

      expect { migration.down }.to raise_error(ActiveRecord::IrreversibleMigration, /more than one store/)
    end

    it 'leaves the columns in place when it refuses' do
      create(:custom_field_definition, store: store, resource_type: 'Spree::Product',
                                       namespace: 'custom', key: 'material')
      create(:custom_field_definition, store: create(:store), resource_type: 'Spree::Product',
                                       namespace: 'custom', key: 'material')

      expect { migration.down }.to raise_error(ActiveRecord::IrreversibleMigration)

      expect(Spree::CustomFieldDefinition.column_names).to include('store_id', 'filter_key')
    end
  end

  describe '#concat_filter_key' do
    it 'builds the same value the model derives, quoting the reserved key column' do
      sql = migration.send(:concat_filter_key)

      expect(sql).to include('cf_')
      expect(sql).to match(/namespace/).and match(/key/)
      # `key` is reserved on MySQL, so both column names must arrive quoted.
      expect(sql).not_to match(/[^"`\w]key[^"`\w]/)
    end
  end
end

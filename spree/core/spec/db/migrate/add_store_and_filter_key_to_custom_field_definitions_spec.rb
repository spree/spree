require 'spec_helper'

# The migration derives filter_key for every pre-existing definition, and two
# different namespace/key splits can flatten to one value. Nothing forbade that
# before the migration, so an existing install can hold a pair the unique index
# would reject — which is data no model can reach once the constraint is on.
RSpec.describe 'AddStoreAndFilterKeyToCustomFieldDefinitions migration' do
  let(:migration) do
    require Spree::Core::Engine.root.join(
      'db', 'migrate', '20260902000001_add_store_and_filter_key_to_custom_field_definitions.rb'
    )
    AddStoreAndFilterKeyToCustomFieldDefinitions.new
  end

  let(:store) { Spree::Store.default }
  let(:table) { Spree::CustomFieldDefinition.table_name }

  def filter_keys_for(*definitions)
    Spree::CustomFieldDefinition.where(id: definitions.map(&:id)).order(:id).pluck(:filter_key)
  end

  describe 'colliding filter keys' do
    # The colliding pair is unreachable once the index the migration adds is
    # in place, so reproduce the pre-migration shape by taking it off.
    around do |example|
      connection = ActiveRecord::Base.connection
      connection.remove_index table, name: 'index_custom_field_definitions_on_store_and_filter_key'

      example.run
    ensure
      Spree::CustomFieldDefinition.delete_all
      connection.add_index table, %i[store_id resource_type filter_key],
                           unique: true, name: 'index_custom_field_definitions_on_store_and_filter_key'
    end

    it 'keeps the first and suffixes every later one' do
      first = create(:custom_field_definition, resource_type: 'Spree::Product', namespace: 'a_b', key: 'c')
      # The colliding row is unreachable through the model once the validation
      # and index are on, so write it the way the migration finds it: a
      # pre-existing row whose namespace/key split flattens to the same value.
      second = create(:custom_field_definition, resource_type: 'Spree::Product', namespace: 'a', key: 'b')
      ActiveRecord::Base.connection.update(
        "UPDATE #{table} SET key = 'b_c', namespace = 'a', filter_key = 'cf_a_b_c' WHERE id = #{second.id}"
      )

      migration.send(:disambiguate_colliding_filter_keys)

      expect(filter_keys_for(first, second)).to eq(%w[cf_a_b_c cf_a_b_c_2])
    end

    it 'leaves the same value in another store alone' do
      mine = create(:custom_field_definition, store: store, resource_type: 'Spree::Product',
                                              namespace: 'custom', key: 'material')
      theirs = create(:custom_field_definition, store: create(:store), resource_type: 'Spree::Product',
                                                namespace: 'custom', key: 'material')

      migration.send(:disambiguate_colliding_filter_keys)

      expect(filter_keys_for(mine, theirs)).to eq(%w[cf_custom_material cf_custom_material])
    end
  end
end

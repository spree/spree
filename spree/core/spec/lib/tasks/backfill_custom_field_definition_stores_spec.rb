require 'spec_helper'
require 'rake'

describe 'spree:upgrade:backfill_custom_field_definition_stores' do
  subject { Rake::Task[task_name] }

  let(:task_name) { 'spree:upgrade:backfill_custom_field_definition_stores' }

  before(:all) do
    Rake::Task.define_task(:environment)
    load Spree::Core::Engine.root.join('lib', 'tasks', 'backfill_custom_field_definition_stores.rake')
  end

  before { subject.reenable }

  let(:store) { Spree::Store.default }

  # The task only ever runs on an install whose migration skipped the NOT NULL
  # constraints because rows were still unowned. Reproduce that state rather
  # than a state the schema forbids: relax the columns, blank them, and put the
  # constraints back so each example starts from the shape it is testing.
  around do |example|
    connection = ActiveRecord::Base.connection
    connection.change_column_null :spree_custom_field_definitions, :store_id, true
    connection.change_column_null :spree_custom_field_definitions, :filter_key, true
    Spree::CustomFieldDefinition.reset_column_information

    example.run
  ensure
    Spree::CustomFieldDefinition.where(store_id: nil).delete_all
    Spree::CustomFieldDefinition.where(filter_key: nil).delete_all
    connection.change_column_null :spree_custom_field_definitions, :store_id, false
    connection.change_column_null :spree_custom_field_definitions, :filter_key, false
    Spree::CustomFieldDefinition.reset_column_information
  end

  # Simulates a pre-6.0 row: the columns exist but nothing has filled them in.
  def strip_tenancy!(*definitions)
    Spree::CustomFieldDefinition.where(id: definitions.map(&:id)).update_all(store_id: nil, filter_key: nil)
  end

  it 'assigns the default store to an unowned definition' do
    definition = create(:custom_field_definition, namespace: 'custom', key: 'material')
    strip_tenancy!(definition)

    subject.invoke

    expect(definition.reload.store).to eq(store)
  end

  it 'backfills the filter_key from the namespace and key' do
    definition = create(:custom_field_definition, namespace: 'specs', key: 'fabric')
    strip_tenancy!(definition)

    subject.invoke

    expect(definition.reload[:filter_key]).to eq('cf_specs_fabric')
  end

  it 'leaves an already-backfilled definition alone' do
    other_store = create(:store)
    definition = create(:custom_field_definition, store: other_store, namespace: 'custom', key: 'material')

    subject.invoke

    expect(definition.reload.store).to eq(other_store)
  end

  it 'skips a definition whose filter_key is already taken in its store' do
    create(:custom_field_definition, resource_type: 'Spree::Product', namespace: 'a_b', key: 'c')
    colliding = create(:custom_field_definition, store: create(:store), resource_type: 'Spree::Product',
                                                 namespace: 'a', key: 'b_c')
    strip_tenancy!(colliding)

    expect { subject.invoke }.to output(/would be cf_a_b_c/).to_stdout

    expect(colliding.reload[:filter_key]).to be_nil
  end

  it 'is idempotent' do
    definition = create(:custom_field_definition, namespace: 'custom', key: 'material')
    strip_tenancy!(definition)

    subject.invoke
    subject.reenable
    subject.invoke

    expect(definition.reload.store).to eq(store)
    expect(definition.reload[:filter_key]).to eq('cf_custom_material')
  end
end

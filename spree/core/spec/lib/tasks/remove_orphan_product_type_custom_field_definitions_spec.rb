require 'spec_helper'
require 'rake'

describe 'spree:upgrade:remove_orphan_product_type_custom_field_definitions' do
  subject { Rake::Task['spree:upgrade:remove_orphan_product_type_custom_field_definitions'] }

  before(:all) do
    Rake::Task.define_task(:environment)
    load Spree::Core::Engine.root.join('lib', 'tasks', 'remove_orphan_product_type_custom_field_definitions.rake')
  end

  before { subject.reenable }

  let(:store) { @default_store }
  let(:product_type) { create(:product_type, store: store) }
  let(:kept_definition) { create(:custom_field_definition, store: store, resource_type: 'Spree::Product') }
  let(:deleted_definition) { create(:custom_field_definition, store: store, resource_type: 'Spree::Product') }
  let!(:kept) { Spree::ProductTypeCustomFieldDefinition.create!(product_type: product_type, custom_field_definition: kept_definition) }
  let!(:orphan) { Spree::ProductTypeCustomFieldDefinition.create!(product_type: product_type, custom_field_definition: deleted_definition) }

  # Simulates a definition deleted before deleting one removed its rows.
  before { Spree::CustomFieldDefinition.unscoped.where(id: deleted_definition.id).delete_all }

  it 'removes rows whose definition is gone and keeps the rest' do
    expect { subject.invoke }.to output(/Removed 1 orphaned custom field row/).to_stdout

    expect(Spree::ProductTypeCustomFieldDefinition.where(id: orphan.id)).to be_empty
    expect(Spree::ProductTypeCustomFieldDefinition.where(id: kept.id)).to exist
  end

  it 'reports nothing to do on a second run' do
    expect { subject.invoke }.to output.to_stdout
    subject.reenable

    expect { subject.invoke }.to output(/Nothing to remove/).to_stdout
  end

  it 'lists a row a callback refused to remove and fails instead of counting it' do
    allow_any_instance_of(Spree::ProductTypeCustomFieldDefinition).to receive(:destroy).and_return(false)

    expect {
      expect { subject.invoke }.to raise_error(SystemExit, /1 row\(s\) could not be removed/)
    }.to output(/Could not remove Spree::ProductTypeCustomFieldDefinition row #{orphan.id} \(product type #{product_type.id}/).to_stdout.and output.to_stderr
    expect(Spree::ProductTypeCustomFieldDefinition.where(id: orphan.id)).to exist
  end

  it 'removes seller requirement rows whose definition is gone' do
    definition = create(:custom_field_definition, store: store, resource_type: 'Spree::Seller')
    requirement = create(:required_custom_fields_requirement, store: store)
    row = Spree::SellerRequirementCustomField.create!(seller_requirement: requirement, custom_field_definition: definition)
    Spree::CustomFieldDefinition.unscoped.where(id: definition.id).delete_all

    expect { subject.invoke }.to output(/Removed 2 orphaned custom field row/).to_stdout
    expect(Spree::SellerRequirementCustomField.where(id: row.id)).to be_empty
  end

  it 'is a step of the 6.0 upgrade' do
    expect(Spree::Upgrade.find_step('remove_orphan_product_type_custom_field_definitions')&.dig('task')).
      to eq('spree:upgrade:remove_orphan_product_type_custom_field_definitions')
  end
end

require 'spec_helper'
require 'rake'

describe 'spree:migrate_media_class_names' do
  subject { Rake::Task[task_name] }

  let(:task_name) { 'spree:migrate_media_class_names' }

  before(:all) do
    Rake::Task.define_task(:environment)
    load Spree::Core::Engine.root.join('lib', 'tasks', 'media_class_rename.rake')
  end

  before { subject.reenable }

  let!(:media) { create(:image) }

  # Simulates a pre-6.0 install: the rows still name the class by its old name.
  def name_rows_legacy!(legacy_name)
    ActiveStorage::Attachment.where(record_id: media.id, record_type: 'Spree::Media').
      update_all(record_type: legacy_name)
  end

  it 'reattaches files whose owner is still named Spree::Asset' do
    name_rows_legacy!('Spree::Asset')

    expect { subject.invoke }.to change {
      ActiveStorage::Attachment.where(record_id: media.id, record_type: 'Spree::Media').count
    }.from(0).to(1)

    expect(media.reload.attachment).to be_attached
  end

  it 'reattaches files whose owner is still named Spree::Image' do
    name_rows_legacy!('Spree::Image')

    subject.invoke

    expect(media.reload.attachment).to be_attached
  end

  it 'rewrites custom field resource types' do
    definition = create(:custom_field_definition, resource_type: 'Spree::Media', key: 'legacy_key')
    custom_field = create(:custom_field, custom_field_definition: definition, resource: media, value: 'x')
    Spree::CustomField.where(id: custom_field.id).update_all(resource_type: 'Spree::Asset')

    subject.invoke

    expect(custom_field.reload.resource_type).to eq('Spree::Media')
  end

  it 'folds a legacy definition into the one that already uses the new name' do
    survivor = create(:custom_field_definition, resource_type: 'Spree::Media', key: 'shared_key')
    legacy = create(:custom_field_definition, resource_type: 'Spree::Media', key: 'shared_key_legacy')
    Spree::CustomFieldDefinition.where(id: legacy.id).
      update_all(resource_type: 'Spree::Asset', key: 'shared_key')
    custom_field = create(:custom_field, custom_field_definition: legacy, resource: media, value: 'y')

    subject.invoke

    expect(Spree::CustomFieldDefinition.exists?(legacy.id)).to be(false)
    expect(custom_field.reload.custom_field_definition_id).to eq(survivor.id)
  end

  it 'is idempotent' do
    name_rows_legacy!('Spree::Asset')
    subject.invoke
    subject.reenable

    expect { subject.invoke }.not_to change {
      ActiveStorage::Attachment.where(record_id: media.id, record_type: 'Spree::Media').count
    }

    expect(media.reload.attachment).to be_attached
  end
end

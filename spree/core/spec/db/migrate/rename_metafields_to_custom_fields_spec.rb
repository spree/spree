require 'spec_helper'

# The rename migration rewrites stored class-name strings. Everything it
# touches is data that no model can reach once the classes are renamed, so it
# is covered here rather than through a model.
RSpec.describe 'RenameMetafieldsToCustomFields migration' do
  let(:migration) do
    require Spree::Core::Engine.root.join('db', 'migrate', '20260809000001_rename_metafields_to_custom_fields.rb')
    RenameMetafieldsToCustomFields.new
  end

  let(:connection) { ActiveRecord::Base.connection }

  describe 'Action Text ownership' do
    let(:product) { create(:product) }
    let(:definition) do
      create(:custom_field_definition, field_type: 'Spree::CustomFields::RichText', namespace: 'custom', key: 'notes')
    end

    # Action Text keys rows by the owner's STI *base* class, so a rich-text
    # custom field's body is stored against `Spree::CustomField`. Rows written
    # before the rename hold `Spree::Metafield` and would be orphaned — the
    # body silently disappearing from the admin — unless the migration
    # rewrites them.
    it 'reattaches bodies stored under the legacy owner class' do
      custom_field = Spree::CustomFields::RichText.new(resource: product, custom_field_definition: definition)
      custom_field.value = '<p>legacy body</p>'
      custom_field.save!

      rich_text_table = ActionText::RichText.table_name
      connection.update(
        "UPDATE #{rich_text_table} SET record_type = 'Spree::Metafield' WHERE record_id = #{custom_field.id}"
      )
      expect(Spree::CustomField.find(custom_field.id).value.body).to be_nil

      migration.send(:rename_action_text_owner, 'Spree::Metafield', 'Spree::CustomField')

      expect(Spree::CustomField.find(custom_field.id).value.body.to_s).to include('legacy body')
    end
  end
end

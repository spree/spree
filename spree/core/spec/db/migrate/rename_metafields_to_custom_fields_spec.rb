require 'spec_helper'

# The rename migration rewrites stored class-name strings and moves rich-text
# bodies out of Action Text. All of it is data no model can reach once the
# classes are renamed, so it is covered here rather than through a model.
RSpec.describe 'RenameMetafieldsToCustomFields migration' do
  include_context 'with legacy Action Text'

  let(:migration) do
    require Spree::Core::Engine.root.join('db', 'migrate', '20260809000001_rename_metafields_to_custom_fields.rb')
    RenameMetafieldsToCustomFields.new
  end

  let(:connection) { ActiveRecord::Base.connection }

  describe 'rich-text values' do
    let(:product) { create(:product) }
    let(:definition) do
      create(:custom_field_definition, field_type: 'Spree::CustomFields::RichText', namespace: 'custom', key: 'notes')
    end

    # Rich text used to live in Action Text, which keys rows by the owner's STI
    # *base* class — so pre-upgrade bodies sit under 'Spree::Metafield'. They
    # have to be copied into the shared `value` column or the content silently
    # disappears from the admin.
    it 'copies bodies stored under the legacy owner class into the value column' do
      custom_field = Spree::CustomFields::RichText.create!(
        resource: product, custom_field_definition: definition, value: 'placeholder'
      )
      connection.insert(<<~SQL.squish)
        INSERT INTO #{ActionText::RichText.table_name} (name, body, record_type, record_id, created_at, updated_at)
        VALUES ('value', '<p>legacy body</p>', 'Spree::Metafield', #{custom_field.id}, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
      SQL
      connection.update(
        "UPDATE #{Spree::CustomField.table_name} SET value = NULL WHERE id = #{custom_field.id}"
      )

      migration.send(:copy_action_text_bodies_into_values)

      expect(custom_field.reload.value).to eq('<p>legacy body</p>')
    end

    it 'leaves rich-text values that were never in Action Text alone' do
      custom_field = Spree::CustomFields::RichText.create!(
        resource: product, custom_field_definition: definition, value: '<p>already migrated</p>'
      )

      migration.send(:copy_action_text_bodies_into_values)

      expect(custom_field.reload.value).to eq('<p>already migrated</p>')
    end
  end
end

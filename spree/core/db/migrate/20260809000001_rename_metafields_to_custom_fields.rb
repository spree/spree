class RenameMetafieldsToCustomFields < ActiveRecord::Migration[7.2]
  # STI class names and the `metafield_type` column both store the Ruby class
  # name. A renamed class cannot load its own legacy rows, so the substitution
  # runs here rather than in the upgrade manifest — after this migration the
  # models are unusable until the strings match.
  TYPE_RENAMES = {
    'Spree::Metafields::ShortText' => 'Spree::CustomFields::ShortText',
    'Spree::Metafields::LongText' => 'Spree::CustomFields::LongText',
    'Spree::Metafields::RichText' => 'Spree::CustomFields::RichText',
    'Spree::Metafields::Number' => 'Spree::CustomFields::Number',
    'Spree::Metafields::Boolean' => 'Spree::CustomFields::Boolean',
    'Spree::Metafields::Json' => 'Spree::CustomFields::Json'
  }.freeze

  def up
    rename_table :spree_metafield_definitions, :spree_custom_field_definitions
    rename_table :spree_metafields, :spree_custom_fields

    rename_column :spree_custom_fields, :metafield_definition_id, :custom_field_definition_id
    rename_column :spree_custom_field_definitions, :metafield_type, :field_type
    rename_column :spree_custom_field_definitions, :name, :label

    rename_index :spree_custom_fields, 'index_metafields_on_resource_and_definition',
                 'index_custom_fields_on_resource_and_definition'

    TYPE_RENAMES.each do |from, to|
      execute_type_rename(:spree_custom_fields, :type, from, to)
      execute_type_rename(:spree_custom_field_definitions, :field_type, from, to)
    end

    # display_on (both/front_end/back_end) collapses to a boolean. Only
    # back_end meant "hide from the storefront"; front_end-only was never a
    # supported value on definitions.
    add_column :spree_custom_field_definitions, :storefront_visible, :boolean, default: true, null: false
    execute(<<~SQL.squish)
      UPDATE spree_custom_field_definitions
      SET storefront_visible = #{quoted_false}
      WHERE display_on = 'back_end'
    SQL
    remove_column :spree_custom_field_definitions, :display_on
  end

  def down
    add_column :spree_custom_field_definitions, :display_on, :string, default: 'both', null: false
    execute(<<~SQL.squish)
      UPDATE spree_custom_field_definitions
      SET display_on = 'back_end'
      WHERE storefront_visible = #{quoted_false}
    SQL
    add_index :spree_custom_field_definitions, :display_on
    remove_column :spree_custom_field_definitions, :storefront_visible

    TYPE_RENAMES.each do |from, to|
      execute_type_rename(:spree_custom_fields, :type, to, from)
      execute_type_rename(:spree_custom_field_definitions, :field_type, to, from)
    end

    rename_index :spree_custom_fields, 'index_custom_fields_on_resource_and_definition',
                 'index_metafields_on_resource_and_definition'

    rename_column :spree_custom_field_definitions, :label, :name
    rename_column :spree_custom_field_definitions, :field_type, :metafield_type
    rename_column :spree_custom_fields, :custom_field_definition_id, :metafield_definition_id

    rename_table :spree_custom_fields, :spree_metafields
    rename_table :spree_custom_field_definitions, :spree_metafield_definitions
  end

  private

  def execute_type_rename(table, column, from, to)
    execute(<<~SQL.squish)
      UPDATE #{quote_table_name(table)}
      SET #{quote_column_name(column)} = #{quote(to)}
      WHERE #{quote_column_name(column)} = #{quote(from)}
    SQL
  end

  def quoted_false
    connection.quoted_false
  end
end

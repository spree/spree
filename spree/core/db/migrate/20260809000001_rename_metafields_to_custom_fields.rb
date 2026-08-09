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

    # Rich-text values move out of Action Text and into the shared `value`
    # column (docs/plans/6.0-rich-text-descriptions.md). Action Text keys rows
    # by the owner's STI base class, so they are found under the pre-rename
    # class name. The source rows are left in place as the rollback path; the
    # table is dropped in 6.1.
    copy_action_text_bodies_into_values

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

    # The Action Text rows were never deleted, so rolling back only needs to
    # clear the copied column.
    clear_rich_text_values

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

  RICH_TEXT_TYPE = 'Spree::CustomFields::RichText'.freeze
  # Action Text stores the owner's STI base class, so rows written before this
  # migration are filed under the pre-rename name.
  LEGACY_ACTION_TEXT_OWNER = 'Spree::Metafield'.freeze

  # A correlated subquery rather than UPDATE ... FROM / UPDATE ... JOIN, which
  # are spelled differently on PostgreSQL, MySQL and SQLite.
  def copy_action_text_bodies_into_values
    return unless connection.table_exists?(:action_text_rich_texts)

    body = <<~SQL.squish
      SELECT #{quote_column_name('body')} FROM #{quote_table_name('action_text_rich_texts')}
      WHERE #{quote_table_name('action_text_rich_texts')}.#{quote_column_name('record_id')} = #{quote_table_name('spree_custom_fields')}.#{quote_column_name('id')}
        AND #{quote_table_name('action_text_rich_texts')}.#{quote_column_name('record_type')} = #{quote(LEGACY_ACTION_TEXT_OWNER)}
        AND #{quote_table_name('action_text_rich_texts')}.#{quote_column_name('name')} = #{quote('value')}
    SQL

    execute(<<~SQL.squish)
      UPDATE #{quote_table_name('spree_custom_fields')}
      SET #{quote_column_name('value')} = (#{body})
      WHERE #{quote_column_name('type')} = #{quote(RICH_TEXT_TYPE)}
        AND EXISTS (#{body})
    SQL
  end

  def clear_rich_text_values
    execute(<<~SQL.squish)
      UPDATE #{quote_table_name('spree_custom_fields')}
      SET #{quote_column_name('value')} = NULL
      WHERE #{quote_column_name('type')} = #{quote(RICH_TEXT_TYPE)}
    SQL
  end

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

namespace :spree do
  # Spree::Asset and Spree::Image became Spree::Media in 6.0. The table rename
  # travels with db:migrate, but the old class names are also written into data:
  # Active Storage's polymorphic owner column, and custom field resource types.
  #
  # The Active Storage rows are the critical ones — every product image and
  # video is attached through `record_type`, so without this step the files are
  # orphaned from their media rows.
  #
  # Idempotent — rows already carrying 'Spree::Media' are left alone.
  desc 'Rewrite stored Spree::Asset / Spree::Image class names to Spree::Media (6.0)'
  task migrate_media_class_names: :environment do
    legacy_names = %w[Spree::Asset Spree::Image]

    # A definition for Spree::Image may already exist alongside one for
    # Spree::Asset with the same namespace and key. Renaming both would violate
    # the definition's uniqueness, so fold the duplicates into the survivor
    # before the bulk rewrite below touches them.
    puts 'Merging duplicate custom field definitions...'
    survivors = Spree::CustomFieldDefinition.where(resource_type: 'Spree::Media').
                index_by { |definition| [definition.namespace, definition.key] }

    Spree::CustomFieldDefinition.transaction do
      Spree::CustomFieldDefinition.where(resource_type: legacy_names).find_each do |definition|
        survivor = survivors[[definition.namespace, definition.key]]
        next if survivor.blank?

        Spree::CustomField.where(custom_field_definition_id: definition.id).
          update_all(custom_field_definition_id: survivor.id)
        definition.delete
      end
    end

    puts 'Rewriting renamed class-name strings...'
    [
      [ActiveStorage::Attachment, :record_type],
      [Spree::CustomField, :resource_type],
      [Spree::CustomFieldDefinition, :resource_type]
    ].each do |model, column|
      legacy_names.each do |legacy_name|
        count = model.where(column => legacy_name).update_all(column => 'Spree::Media')
        puts "  #{model.table_name}.#{column}: #{count} rows #{legacy_name} -> Spree::Media"
      end
    end

    puts 'Done!'
  end
end

# frozen_string_literal: true

# Deleting a custom field definition used to leave its product type join rows
# behind. Rows pointing at a missing definition made serializing the product
# type raise.
namespace :spree do
  desc 'Remove product type custom field rows whose custom field definition no longer exists'
  task remove_orphan_product_type_custom_field_definitions: :environment do
    orphans = Spree::ProductTypeCustomFieldDefinition.where.not(
      custom_field_definition_id: Spree::CustomFieldDefinition.unscoped.select(:id)
    )
    removed = 0

    orphans.find_each do |join|
      join.destroy
      removed += 1
    end

    puts "remove_orphan_product_type_custom_field_definitions done. removed: #{removed}"
  end
end

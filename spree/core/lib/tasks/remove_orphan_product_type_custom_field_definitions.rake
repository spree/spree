# frozen_string_literal: true

# Deleting a custom field definition used to leave its product type join rows
# behind. Rows pointing at a missing definition made serializing the product
# type raise. Deleting a definition now removes them; this clears the ones left
# by earlier deletions. Runs as a step of `spree:upgrade`.
namespace :spree do
  namespace :upgrade do
    desc <<~DESC
      Removes product type custom field rows whose custom field definition no
      longer exists. Deleting a definition used to leave them behind, and they
      made the product type's API responses fail. Idempotent — a
      second run finds nothing.
    DESC
    task remove_orphan_product_type_custom_field_definitions: :environment do
      orphans = Spree::ProductTypeCustomFieldDefinition.unscoped.where.not(
        custom_field_definition_id: Spree::CustomFieldDefinition.unscoped.select(:id)
      )
      removed = 0
      failed = []

      orphans.find_each do |join|
        if join.destroy
          removed += 1
        else
          failed << join
        end
      end

      failed.each do |join|
        puts "  Could not remove product type custom field row #{join.id} " \
             "(product type #{join.product_type_id}, missing definition #{join.custom_field_definition_id}): " \
             "#{join.errors.full_messages.to_sentence.presence || 'a callback stopped the removal'}"
      end

      puts removed.zero? && failed.empty? ? '  Nothing to remove.' : "  Removed #{removed} orphaned product type custom field row(s)."
      # Fail the step, so `spree:upgrade` stops before recording the upgrade as
      # done while a row that breaks product type responses is still there.
      abort "  #{failed.size} row(s) could not be removed, see above." if failed.any?
    end
  end
end

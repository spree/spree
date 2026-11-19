# frozen_string_literal: true

# Deleting a custom field definition used to leave the rows that attach it to
# product types and seller requirements behind. Rows pointing at a missing
# definition made serializing the product type raise. Deleting a definition now
# removes them; this clears the ones left by earlier deletions. Runs as a step
# of `spree:upgrade`.
namespace :spree do
  namespace :upgrade do
    desc <<~DESC
      Removes product type and seller requirement custom field rows whose
      custom field definition no longer exists. Deleting a definition used to
      leave them behind, and they made the product type's API responses fail.
      Idempotent — a second run finds nothing.
    DESC
    task remove_orphan_product_type_custom_field_definitions: :environment do
      existing_definitions = Spree::CustomFieldDefinition.unscoped.select(:id)
      removed = 0
      failed = []

      [Spree::ProductTypeCustomFieldDefinition, Spree::SellerRequirementCustomField].each do |join_class|
        join_class.unscoped.where.not(custom_field_definition_id: existing_definitions).find_each do |join|
          if join.destroy
            removed += 1
          else
            failed << join
          end
        end
      end

      failed.each do |join|
        owner = join.respond_to?(:product_type_id) ? "product type #{join.product_type_id}" : "seller requirement #{join.seller_requirement_id}"
        puts "  Could not remove #{join.class.name} row #{join.id} " \
             "(#{owner}, missing definition #{join.custom_field_definition_id}): " \
             "#{join.errors.full_messages.to_sentence.presence || 'a callback stopped the removal'}"
      end

      puts removed.zero? && failed.empty? ? '  Nothing to remove.' : "  Removed #{removed} orphaned custom field row(s)."
      # Fail the step, so `spree:upgrade` stops before recording the upgrade as
      # done while a row that breaks product type responses is still there.
      abort "  #{failed.size} row(s) could not be removed, see above." if failed.any?
    end
  end
end

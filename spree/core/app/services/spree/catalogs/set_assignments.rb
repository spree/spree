module Spree
  module Catalogs
    # Replaces a catalog's audience with the given set.
    #
    # An audience absent from the payload is withdrawn, so the whole set
    # arrives in one request — the agreement editor stages every change
    # behind the catalog's Save, and applying half of them would show the
    # agreement to people the merchant never confirmed.
    class SetAssignments
      prepend Spree::ServiceModule::Base

      # @param catalog [Spree::Catalog]
      # @param assignables [Array<Spree::CustomerGroup, Spree::Company>] the
      #   audiences this catalog should be shown to, resolved by the caller
      #   through the store so another tenant's record cannot reach here
      # @return [Spree::ServiceModule::Result] value is the catalog
      def call(catalog:, assignables:)
        keys = Array(assignables).map { |record| [record.class.base_class.name, record.id] }
        invalid = nil

        ApplicationRecord.transaction do
          withdraw(catalog, keys)

          keys.zip(Array(assignables)).each do |(type, id), record|
            next if catalog.catalog_assignments.exists?(assignable_type: type, assignable_id: id)

            assignment = catalog.catalog_assignments.new(assignable: record)
            next if assignment.save

            # A plain service's `failure` returns rather than raising, so one
            # bad row has to take the transaction down itself — otherwise the
            # rest of the set commits and the caller is told it all worked.
            invalid = assignment
            raise ActiveRecord::Rollback
          end
        end

        return failure(invalid) if invalid

        success(catalog.reload)
      end

      private

      # Rows the payload no longer names. Deleted per row rather than in one
      # NOT IN clause, because the pair is polymorphic and an id means
      # nothing without its type.
      def withdraw(catalog, keys)
        kept = keys.to_set

        catalog.catalog_assignments.find_each do |assignment|
          next if kept.include?([assignment.assignable_type, assignment.assignable_id])

          assignment.destroy!
        end
      end
    end
  end
end

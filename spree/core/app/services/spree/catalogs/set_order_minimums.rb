module Spree
  module Catalogs
    # Replaces a catalog's order minimums with the given set.
    #
    # A currency absent from the payload has its minimum lifted, so the whole
    # set arrives in one request — the agreement editor stages every term
    # behind the catalog's Save, and applying half of them would leave the
    # agreement in a state the merchant never asked for.
    class SetOrderMinimums
      prepend Spree::ServiceModule::Base

      # @param catalog [Spree::Catalog]
      # @param order_minimums [Array<Hash>] :currency, :amount
      # @return [Spree::ServiceModule::Result] value is the catalog
      def call(catalog:, order_minimums:)
        rows = Array(order_minimums).reject { |row| row[:currency].blank? }

        invalid = nil

        ApplicationRecord.transaction do
          keep = rows.map { |row| row[:currency].to_s.upcase }
          catalog.order_minimums.where.not(currency: keep).destroy_all if keep.any?
          catalog.order_minimums.destroy_all if keep.empty?

          rows.each do |row|
            minimum = catalog.order_minimums.find_or_initialize_by(currency: row[:currency].to_s.upcase)
            minimum.amount = row[:amount]
            next if minimum.save

            # A plain service's `failure` returns rather than raising, so a
            # bad row has to take the transaction down itself — otherwise the
            # rest of the set applies and the caller is told it all worked.
            invalid = minimum
            raise ActiveRecord::Rollback
          end
        end

        return failure(invalid) if invalid

        success(catalog.reload)
      end
    end
  end
end

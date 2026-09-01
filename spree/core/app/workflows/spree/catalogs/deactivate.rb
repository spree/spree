module Spree
  module Catalogs
    # Takes an agreement out of effect. Its audience stops seeing its
    # assortment and stops getting its prices; the catalog and everything it
    # holds — assignments, terms, its price list — survive untouched, so
    # activating again resumes exactly what was there.
    #
    # Deactivating is never refused: an agreement that has to stop applying
    # has to be able to stop, whatever state it is in.
    class Deactivate < Spree::Workflow
      hooks :validate, :after_deactivate

      # @param catalog [Spree::Catalog]
      # @return [Spree::ServiceModule::Result] value is the catalog
      def perform(catalog:)
        super

        run_hooks :validate

        ApplicationRecord.transaction do
          step :mark_inactive
          run_hooks :after_deactivate
        end

        success(catalog)
      end

      private

      def mark_inactive
        failure(catalog) unless catalog.update(active: false)
      end
    end
  end
end

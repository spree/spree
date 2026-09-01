module Spree
  module Catalogs
    # Puts an agreement into effect: from here its audience sees its
    # assortment and pays its prices.
    #
    # A workflow rather than a column write, so what has to happen alongside —
    # sweeping a buyer's cached catalog set, telling the companies it covers —
    # attaches to `after_activate` instead of being scattered across every
    # caller that flips the flag (docs/plans/6.0-catalog-agreement-rework.md).
    class Activate < Spree::Workflow
      hooks :validate, :after_activate

      # @param catalog [Spree::Catalog]
      # @return [Spree::ServiceModule::Result] value is the catalog
      def perform(catalog:)
        super

        step :require_someone_to_apply_to
        run_hooks :validate

        ApplicationRecord.transaction do
          step :mark_active
          run_hooks :after_activate
        end

        success(catalog)
      end

      private

      # An agreement nobody is assigned to reaches no buyer, so activating it
      # would change nothing — refused, so the emptiness reads as the mistake
      # it is rather than as a catalog that quietly does nothing.
      #
      # A channel's default catalog is the exception the rule needs: it is
      # reached through the channel rather than through an assignment, and it
      # is the whole mechanism behind channel-wide pricing.
      def require_someone_to_apply_to
        return if catalog.catalog_assignments.exists?
        return if Spree::Channel.exists?(default_catalog_id: catalog.id)

        catalog.errors.add(:base, :no_audience)
        failure(catalog)
      end

      def mark_active
        failure(catalog) unless catalog.update(active: true)
      end
    end
  end
end

module Spree
  module Imports
    # Prices for one price list, one rung per row, merged into the list: a row
    # writes or updates its rung, a blank price removes it, and rungs the file
    # does not mention stay as they are (docs/plans/6.0-volume-pricing.md).
    #
    # The list is a preference rather than a column because it is the only
    # import type with a parent, and the same serialized store already carries
    # the other per-type settings.
    class PriceListPrices < Spree::Import
      preference :price_list_id, :string, default: nil

      # On create only: the list can be deleted while rows are still being
      # processed, and the import must still be able to finish (its rows fail
      # with a message) and to be deleted afterwards.
      validate :price_list_present, on: :create

      def row_processor_class
        Spree::Imports::RowProcessors::PriceListPrice
      end

      # Every rung of a variant is processed together, so the break cap is
      # judged on the whole ladder the file carries for it.
      def group_column
        'sku'
      end

      def model_class
        Spree::Price
      end

      def self.model_class
        Spree::Price
      end

      # Price lists are gated by the products scope family, like their own
      # endpoints (see Admin::PriceListsController).
      def self.required_scope
        :products
      end

      # The list being written. Read through the store, so a preference
      # pointing at another store's list answers nil and the import is refused.
      #
      # @return [Spree::PriceList, nil]
      def price_list
        return if preferred_price_list_id.blank? || store.nil?

        store.price_lists.find_by(id: preferred_price_list_id)
      end

      # @param list [Spree::PriceList, nil]
      def price_list=(list)
        self.preferred_price_list_id = list&.id&.to_s
      end

      # The list's public id without loading it — the serializer emits this
      # on every poll, and the id was resolved through the store at create.
      #
      # @return [String, nil]
      def price_list_prefixed_id
        Spree::PriceList.prefixed_id_for(preferred_price_list_id) if preferred_price_list_id.present?
      end

      private

      def price_list_present
        errors.add(:price_list, :blank) if price_list.nil?
      end
    end
  end
end

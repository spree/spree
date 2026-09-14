module Spree
  module Api
    module V3
      module Seller
        # The narrowing every seller-branch catalog write shares.
        #
        # A seller's payload names ids the model would happily resolve across
        # the whole store — a warehouse, a delivery profile, a product type —
        # because the model is written for the operator, whose store IS the
        # tenant. On this branch the tenant is a seller inside that store, so
        # each id is resolved here, where `current_seller` is known
        # (docs/plans/6.0-seller-master-catalog-listings.md).
        #
        # Shared by the products controller (a seller's own listings) and the
        # variants controller (their offers on the marketplace's).
        module CatalogParams
          extend ActiveSupport::Concern

          protected

          # A price the client did not name a currency for is priced in the
          # store's. `Variant#prices=` matches base prices on the currency it
          # is handed and drops the ones missing from the payload, so a
          # guessed currency does not merely add a stray price — it removes
          # the right one. Blank counts as unnamed: an empty form field would
          # otherwise key a price on "".
          #
          # @param prices [Array<Hash>, nil]
          # @return [Array<Hash>, nil]
          def default_price_currencies(prices)
            return prices if prices.blank?

            prices.map do |price|
              price[:currency].present? ? price : price.merge(currency: Spree::Current.currency)
            end
          end

          # Stock belongs to the warehouse it sits in, and a seller has their
          # own. `Variant#stock_levels=` resolves a location against the
          # product's *store*, which on a marketplace spans every seller — so
          # a payload naming somebody else's warehouse would write into it.
          #
          # A warehouse this seller does not hold is a 404, not a silent drop:
          # answering 200 while quietly writing no stock leaves a merchant
          # believing they stocked something they did not. Matches how
          # `own_product_type_id` and `own_delivery_profile_id` treat an id
          # that cannot exist for this seller.
          #
          # @param stock_levels [Array<Hash>, nil]
          # @raise [ActiveRecord::RecordNotFound] on a warehouse elsewhere
          # @return [Array<Hash>, nil]
          def own_stock_levels(stock_levels)
            return stock_levels if stock_levels.blank?

            own_ids = current_seller.stock_locations.pluck(:id).to_set

            stock_levels.each do |level|
              id = Spree::StockLocation.decode_own_prefixed_id(level[:stock_location_id])
              next if id.present? && own_ids.include?(id)

              raise ActiveRecord::RecordNotFound,
                    "Stock location #{level[:stock_location_id]} does not belong to this seller"
            end
          end

          # A type is picked from the marketplace's own list, so the id is
          # resolved against this seller's store rather than handed to the
          # model: a type from another store would seed its option types onto
          # the product, and a picker value that cannot exist for this seller
          # is a 404, not a validation error. Blank detaches the type.
          #
          # @param value [String, nil]
          # @return [Integer, String, nil]
          def own_product_type_id(value)
            return nil if value.blank?

            current_store.product_types.find_by_prefix_id!(value).id
          end

          # The same, for a delivery profile. A product always carries one, so
          # blank is left for the model to refuse; on a variant blank means
          # "ship as the master does", which the model resolves.
          #
          # @param value [String, nil]
          # @return [Integer, String, nil]
          def own_delivery_profile_id(value)
            return nil if value.blank?

            current_store.delivery_profiles.find_by_prefix_id!(value).id
          end
        end
      end
    end
  end
end

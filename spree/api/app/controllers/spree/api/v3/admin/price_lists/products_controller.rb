module Spree
  module Api
    module V3
      module Admin
        module PriceLists
          # The products a price list covers — the uniform nested membership
          # surface (see Spree::Api::V3::Admin::ProductMembership). Membership
          # is derived from the list's price rows: adding a product
          # materializes a placeholder price for every variant × store
          # currency (the spreadsheet's empty cells), removing hard-deletes
          # its price rows. Unordered — a price list prices, it never
          # merchandises — so listing is by name.
          class ProductsController < ResourceController
            include Spree::Api::V3::Admin::ProductMembership

            # Price lists ride the products scope like their parent
            # controller — no separate read_price_lists scope.
            scoped_resource :products

            protected

            def serializer_class
              Spree.api.admin_price_list_product_serializer
            end

            # The resolver rides along in the serializer params, preloaded
            # with this page's variants — one query for the page rather than
            # one per row (see Catalogs::ProductsController, the same shape).
            def serializer_params
              return super unless expanded_keys.include?('price_list_price')

              super.merge(price_list_price_resolver: price_list_price_resolver)
            end

            # The list read as it stands, draft or not: this is its editor.
            def price_list_price_resolver
              @price_list_price_resolver ||=
                Spree::Catalogs::ResolvePrices.new(price_list: @price_list, currency: current_currency).
                tap { |resolver| resolver.preload(priced_variants) }
            end

            def priced_variants
              Array(@collection).flat_map { |product| product.variants.to_a }
            end

            # Every row lists its variants and prices each of them, so what
            # the rows read comes down with the page: the prices the resolver
            # picks from, the option values that name the variant, the stock
            # levels behind the flags. `default_variant` separately, since it
            # is its own belongs_to with a cache of its own.
            # Only what this page reads: the card's thumbnail, and every
            # variant with the rows and option values the resolver and the
            # variant rows need. `default_variant` is deliberately absent —
            # it is a separate `belongs_to` with a cache of its own, so
            # reading it here would re-query option values per row. Publications, stock levels and the default
            # variant's own prices are deliberately absent — the serializer
            # here is not the admin product serializer and never asks for them.
            def collection_includes
              [
                :primary_media,
                { variants: [:prices, { option_values: :option_type }] }
              ]
            end

            # DISTINCT (the base default): a product joins once per
            # variant × currency price row.
            def scope
              product_scope.
                joins(variants: :prices).
                where(Spree::Price.table_name => { price_list_id: @price_list.id }).
                order(:name)
            end

            def add_member_products(products)
              @price_list.add_products(products.map(&:id))
            end

            def remove_member_products(products)
              @price_list.remove_products(products.map(&:id))
            end

            def set_parent
              @price_list = current_store.price_lists.
                            accessible_by(current_ability, parent_ability_action).
                            find_by_prefix_id!(params[:price_list_id])
              authorize_parent!(@price_list)
            end
          end
        end
      end
    end
  end
end

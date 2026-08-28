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

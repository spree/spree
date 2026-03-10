module Spree
  module Api
    module V3
      module Store
        module Categories
          class ProductsController < Store::ProductsController
            before_action :set_category

            protected

            def set_category
              @category = find_category
            end

            def scope
              super.in_category(@category)
            end

            private

            def find_category
              id = params[:category_id]
              category_scope = Spree::Category.for_store(current_store).accessible_by(current_ability, :show)
              category_scope = category_scope.i18n if Spree::Category.include?(Spree::TranslatableResource)

              if id.to_s.start_with?('txn_')
                category_scope.find_by_prefix_id!(id)
              else
                find_with_fallback_default_locale { category_scope.i18n.find_by!(permalink: id) }
              end
            end
          end
        end
      end
    end
  end
end

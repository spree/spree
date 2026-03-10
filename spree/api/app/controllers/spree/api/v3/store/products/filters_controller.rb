module Spree
  module Api
    module V3
      module Store
        module Products
          class FiltersController < Store::BaseController
            def index
              aggregator = Spree::Api::V3::FiltersAggregator.new(
                scope: filters_scope,
                currency: current_currency,
                category: category
              )
              render json: aggregator.call
            end

            private

            # Build scope from category and/or ransack params
            # @return [ActiveRecord::Relation]
            def filters_scope
              scope = current_store.products.active(current_currency)
              scope = scope.in_category(category) if category.present?
              scope = scope.ransack(params[:q]).result if params[:q].present?
              scope.accessible_by(current_ability, :show)
            end

            # Fetches category from params
            # @param [String] category_id
            # @return [Spree::Category]
            def category
              category_id = params[:category_id]
              @category ||= category_id.present? ? current_store.categories.find_by_param(category_id) : nil
            end
          end
        end
      end
    end
  end
end

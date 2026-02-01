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
                taxon: taxon
              )
              render json: aggregator.call
            end

            private

            # Build scope from taxon and/or ransack params
            def filters_scope
              scope = current_store.products.available(Time.current, current_currency)
              scope = scope.in_taxon(taxon) if taxon.present?
              scope = scope.ransack(params[:q]).result if params[:q].present?
              scope.accessible_by(current_ability, :show)
            end

            def taxon
              @taxon ||= params[:taxon_id].present? ? current_store.taxons.find_by_param(params[:taxon_id]) : nil
            end
          end
        end
      end
    end
  end
end

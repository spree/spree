module Spree
  module Admin
    module TaxonsHelper
      def taxons_scope
        @taxons_scope ||= current_store.taxons.where(automatic: false).where.not(parent_id: nil)
      end

      def taxons_options_json_array
        taxons_scope.pluck(:id, :pretty_name).map { |id, pretty_name| { id: id, name: pretty_name } }.as_json
      end

      def taxon_sort_options_for_select
        @taxon_sort_options_for_select ||= Spree::Taxon::SORT_ORDERS.map do |sort_order|
          [
            Spree.t("products_sort_options.#{sort_order.underscore}"),
            sort_order
          ]
        end
      end
    end
  end
end

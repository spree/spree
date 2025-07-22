module Spree
  module Admin
    module TaxonsHelper
      def taxons_scope(with_automatic: false)
        @memoized_taxons_scope ||= {}
        @memoized_taxons_scope[with_automatic] ||= begin
          scope = current_store.taxons.where.not(parent_id: nil)
          scope = scope.where(automatic: false) unless with_automatic
          scope
        end
      end

      def taxons_options_json_array(with_automatic: false)
        taxons_scope(with_automatic: with_automatic).pluck(:id, :pretty_name).map { |id, pretty_name| { id: id, name: pretty_name } }.as_json
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

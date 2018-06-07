module Spree
  module Taxons
    class Find
      def initialize(taxons, params)
        @taxons = taxons
        @params = params
      end

      def execute
        taxons = @taxons

        taxons = by_ids(taxons)      if ids?
        taxons = by_taxonomy(taxons) if taxonomy?
        taxons = by_roots(taxons)    if roots?

        taxons
      end

      private

      attr_accessor :params

      def ids?
        params[:ids].present?
      end

      def taxonomy?
        params[:taxonomy_id].present?
      end

      def roots?
        params[:roots].present?
      end

      def ids
        params[:ids].split(',')
      end

      def by_ids(taxons)
        taxons.where(id: ids)
      end

      def by_taxonomy(taxons)
        taxons.where(parent_id: params[:taxonomy_id])
      end

      def by_roots(taxons)
        taxons.roots
      end
    end
  end
end

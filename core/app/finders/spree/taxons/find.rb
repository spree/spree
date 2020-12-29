module Spree
  module Taxons
    class Find
      def initialize(scope:, params:)
        @scope = scope
        @ids      = String(params.dig(:filter, :ids)).split(',')
        @parent   = params.dig(:filter, :parent_id)
        @taxonomy = params.dig(:filter, :taxonomy_id)
        @name     = params.dig(:filter, :name)
        @roots    = params.dig(:filter, :roots)
      end

      def execute
        taxons = by_ids(scope)
        taxons = by_parent(taxons)
        taxons = by_taxonomy(taxons)
        taxons = by_roots(taxons)
        taxons = by_name(taxons)

        taxons
      end

      private

      attr_reader :ids, :parent, :taxonomy, :roots, :name, :scope

      def ids?
        ids.present?
      end

      def parent?
        parent.present?
      end

      def taxonomy?
        taxonomy.present?
      end

      def roots?
        roots.present?
      end

      def name?
        name.present?
      end

      def name_matcher
        Spree::Taxon.arel_table[:name].matches("%#{name}%")
      end

      def by_ids(taxons)
        return taxons unless ids?

        taxons.where(id: ids)
      end

      def by_parent(taxons)
        return taxons unless parent?

        taxons.where(parent_id: parent)
      end

      def by_taxonomy(taxons)
        return taxons unless taxonomy?

        taxons.where(taxonomy_id: taxonomy)
      end

      def by_roots(taxons)
        return taxons unless roots?

        taxons.roots
      end

      def by_name(taxons)
        return taxons unless name?

        taxons.where(name_matcher)
      end
    end
  end
end

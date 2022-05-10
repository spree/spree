module Spree
  module Taxons
    class Find
      def initialize(scope:, params:)
        @scope = scope
        @ids              = String(params.dig(:filter, :ids)).split(',')
        @parent           = params.dig(:filter, :parent_id)
        @parent_permalink = params.dig(:filter, :parent_permalink)
        @taxonomy         = params.dig(:filter, :taxonomy_id)
        @name             = params.dig(:filter, :name)
        @roots            = params.dig(:filter, :roots)
      end

      def execute
        taxons = by_ids(scope)
        taxons = by_parent(taxons)
        taxons = by_parent_permalink(taxons)
        taxons = by_taxonomy(taxons)
        taxons = by_roots(taxons)
        taxons = by_name(taxons)

        taxons.distinct
      end

      private

      attr_reader :ids, :parent, :parent_permalink, :taxonomy, :roots, :name, :scope

      def ids?
        ids.present?
      end

      def parent?
        parent.present?
      end

      def parent_permalink?
        parent_permalink.present?
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

      def by_parent_permalink(taxons)
        return taxons unless parent_permalink?

        if Rails::VERSION::STRING >= '6.1'
          taxons.joins(:parent).where(parent: { permalink: parent_permalink })
        else
          taxons.joins("INNER JOIN #{Spree::Taxon.table_name} AS parent_taxon ON parent_taxon.id = #{Spree::Taxon.table_name}.parent_id").where(["parent_taxon.permalink = ?", parent_permalink])
        end
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

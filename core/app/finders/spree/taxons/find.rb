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

        if Spree.use_translations?
          taxons.joins(:parent).
            join_translation_table(Taxon, 'parents_spree_taxons').
            where(Taxon.translation_table_alias => { permalink: parent_permalink })
        else
          taxons.joins(:parent).where(parent: { permalink: parent_permalink })
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

        taxon_name = name

        # i18n mobility scope doesn't automatically get set for query blocks (Mobility issue #599) - set it explicitly
        taxons.i18n { name.matches("%#{taxon_name}%") }
      end
    end
  end
end

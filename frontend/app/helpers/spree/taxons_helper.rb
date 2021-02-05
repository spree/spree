module Spree
  module TaxonsHelper
    # Retrieves the collection of products to display when "previewing" a taxon.  This is abstracted into a helper so
    # that we can use configurations as well as make it easier for end users to override this determination.  One idea is
    # to show the most popular products for a particular taxon (that is an exercise left to the developer.)
    def taxon_preview(taxon, max = 4)
      ActiveSupport::Deprecation.warn(<<-DEPRECATION, caller)
        TaxonsHelper#taxon_preview is deprecated and will be removed in Spree 5.0.
        Please remove any `helper 'spree/taxons'` from your controllers.
      DEPRECATION
      products = taxon.active_products.distinct.select('spree_products.*, spree_products_taxons.position').limit(max)
      if products.size < max
        products_arel = Spree::Product.arel_table
        taxon.descendants.each do |child|
          to_get = max - products.length
          products += child.active_products.distinct.select('spree_products.*, spree_products_taxons.position').where(products_arel[:id].not_in(products.map(&:id))).limit(to_get)
          break if products.size >= max
        end
      end
      products
    end

    def taxons_tree(root_taxon, current_taxon, max_level = 1)
      ActiveSupport::Deprecation.warn(<<-DEPRECATION, caller)
        TaxonsHelper#taxons_tree is deprecated and will be removed in Spree 5.0.
        Please remove any `helper 'spree/taxons'` from your controllers.
      DEPRECATION

      return '' if max_level < 1 || root_taxon.leaf?

      content_tag :div, class: 'list-group' do
        taxons = root_taxon.children.map do |taxon|
          css_class = current_taxon&.self_and_ancestors&.include?(taxon) ? 'list-group-item list-group-item-action active' : 'list-group-item list-group-item-action'
          link_to(taxon.name, seo_url(taxon), class: css_class) + taxons_tree(taxon, current_taxon, max_level - 1)
        end
        safe_join(taxons, "\n")
      end
    end
  end
end

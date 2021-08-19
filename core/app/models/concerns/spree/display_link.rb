module Spree
  module DisplayLink
    def link
      case linked_resource_type
      when 'Spree::Taxon'
        return if linked_resource&.permalink.blank?

        if spree_routes.method_defined?(:nested_taxons_path)
          spree_routes.nested_taxons_path(linked_resource.permalink)
        else
          "/#{Spree::Config[:storefront_taxons_path]}/#{linked_resource.permalink}"
        end
      when 'Spree::Product'
        return if linked_resource&.slug.blank?

        if spree_routes.method_defined?(:products_path)
          spree_routes.product_path(linked_resource)
        else
          "/#{Spree::Config[:storefront_products_path]}/#{linked_resource.slug}"
        end
      when 'Spree::CmsPage'
        return if linked_resource&.slug.blank?

        if spree_routes.method_defined?(:page_path)
          spree_routes.page_path(linked_resource.slug)
        else
          "/#{Spree::Config[:storefront_pages_path]}/#{linked_resource.slug}"
        end
      when 'Home Page'
        '/'
      when 'URL'
        destination
      end
    end

    private

    def spree_routes
      Spree::Core::Engine.routes.url_helpers
    end
  end
end

module Spree
  module DisplayLink
    def link
      case linked_resource_type
      when 'Spree::Taxon'
        return if linked_resource.nil?

        if defined?(SpreeFrontend)
          Spree::Core::Engine.routes.url_helpers.nested_taxons_path(linked_resource.permalink)
        else
          "/#{Spree::Config[:storefront_taxons_path]}/#{linked_resource.permalink}"
        end
      when 'Spree::Product'
        return if linked_resource.nil?

        if defined?(SpreeFrontend)
          Spree::Core::Engine.routes.url_helpers.product_path(linked_resource)
        else
          "/#{Spree::Config[:storefront_products_path]}/#{linked_resource.slug}"
        end
      when 'Home Page'
        '/'
      when 'URL'
        destination
      end
    end
  end
end

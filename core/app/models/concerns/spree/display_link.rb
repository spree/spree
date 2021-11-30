module Spree
  module DisplayLink
    belongs_to :linked_resource, polymorphic: true

    def link
      case linked_resource_type
      when 'Spree::Taxon'
        return if linked_resource&.permalink.blank?

        "/#{Spree::Config[:storefront_taxons_path]}/#{linked_resource.permalink}"
      when 'Spree::Product'
        return if linked_resource&.slug.blank?

        "/#{Spree::Config[:storefront_products_path]}/#{linked_resource.slug}"
      when 'Spree::CmsPage'
        return if linked_resource&.slug.blank?

        "/#{Spree::Config[:storefront_pages_path]}/#{linked_resource.slug}"
      when 'Spree::Linkable::HomePage'
        '/'
      when 'Spree::Linkable::Uri'
        destination
      end
    end
  end
end

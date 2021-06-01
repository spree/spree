module Spree::Cms::Sections
  class FeaturedArticle < Spree::CmsSection
    after_initialize :default_values

    def links_to
      ['Spree::Taxon', 'Spree::Product']
    end

    def widths
      ['Edge-to-Edge', 'Full', 'Half']
    end

    private

    def default_values
      self.width ||= 'Edge-to-Edge'
      self.linked_resource_type ||= 'Spree::Taxon'
    end
  end
end

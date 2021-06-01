module Spree::Cms::Sections
  class CategoryBannerSquare < Spree::CmsSection
    after_initialize :default_values

    has_one_attached :upper_image
    has_one_attached :lower_image

    def links_to
      ['Spree::Taxon', 'Spree::Product']
    end

    def widths
      ['Half']
    end

    private

    def default_values
      self.width ||= 'Half'
      self.linked_resource_type ||= 'Spree::Taxon'
    end
  end
end

module Spree
  class CmsSection < Spree::Base
    include Spree::DisplayLink

    acts_as_list scope: :cms_page
    belongs_to :cms_page

    belongs_to :linked_resource, polymorphic: true

    default_scope { order(position: :asc) }

    TYPES = ['Spree::Cms::Sections::Hero',
             'Spree::Cms::Sections::Promo',
             'Spree::Cms::Sections::FeaturedArticle',
             'Spree::Cms::Sections::Carousel',
             'Spree::Cms::Sections::CategoryBannerSquare',
             'Spree::Cms::Sections::CategoryBannerTall']

    # Overide this per section type
    def links_to
      []
    end

    # Overide this per section type
    def boundaries
      ['Container', 'Screen']
    end

    # Overide this per section type
    def widths
      ['Full', 'Half']
    end
  end
end

module Spree
  class CmsSection < Spree::Base
    include Spree::DisplayLink

    acts_as_list scope: :cms_page
    belongs_to :cms_page, touch: true

    # Six images in one section should cover a large number of potential use cases.
    # The standardization of putting them here means we can offer them up through
    # the API serializer vs hoping they get added per section basis and the naming
    # matches those used in the API serializer attributes.
    has_one_attached :image_one
    has_one_attached :image_two
    has_one_attached :image_three
    has_one_attached :image_four
    has_one_attached :image_five
    has_one_attached :image_six

    belongs_to :linked_resource, polymorphic: true

    default_scope { order(position: :asc) }

    LINKED_RESOURCE_TYPE = []

    TYPES = ['Spree::Cms::Sections::FullScreenHeroImage',
             'Spree::Cms::Sections::HalfScreenPromotionBlock',
             'Spree::Cms::Sections::FeaturedArticle',
             'Spree::Cms::Sections::ProductCarousel',
             'Spree::Cms::Sections::ThreeTaxonCategoriesBlock',
             'Spree::Cms::Sections::StaticBrandingBar']

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

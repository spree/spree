module Spree
  class CmsSection < Spree::Base
    include Spree::DisplayLink

    IMAGE_TYPES = ['image/png', 'image/jpg', 'image/jpeg', 'image/gif'].freeze

    acts_as_list scope: :cms_page
    belongs_to :cms_page, touch: true

    # Six images in one section should cover a large number of potential use cases.
    # The standardization of putting them here means we can offer them up through
    # the API serializer vs hoping they get added on a per-section basis and the naming
    # matches those used in the API serializer attributes.
    has_one_attached :image_one
    has_one_attached :image_two
    has_one_attached :image_three
    has_one_attached :image_four
    has_one_attached :image_five
    has_one_attached :image_six

    belongs_to :linked_resource, polymorphic: true

    default_scope { order(position: :asc) }

    validates :name, :cms_page, presence: true

    validates :image_one, :image_two, :image_three, :image_four,
              :image_five, :image_six, content_type: IMAGE_TYPES

    LINKED_RESOURCE_TYPE = []

    TYPES = ['Spree::Cms::Sections::HeroImage',
             'Spree::Cms::Sections::FeaturedArticle',
             'Spree::Cms::Sections::ProductCarousel',
             'Spree::Cms::Sections::ImageGallery',
             'Spree::Cms::Sections::SideBySideImages',
             'Spree::Cms::Sections::RichTextContent']

    def boundaries
      ['Container', 'Screen']
    end

    def css_classes
      ['row', 'section-row'].compact
    end

    def gutters_sizes
      ['Gutters', 'No Gutters']
    end

    def fullscreen?
      fit == 'Screen'
    end
  end
end

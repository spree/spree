module Spree
  class CmsSection < Base
    include DisplayLink

    acts_as_list scope: :cms_page
    belongs_to :cms_page, touch: true

    validate :reset_link_attributes

    IMAGE_COUNT = ['one', 'two', 'three']
    IMAGE_TYPES = ['image/png', 'image/jpg', 'image/jpeg', 'image/gif'].freeze
    IMAGE_SIZE = ['sm', 'md', 'lg', 'xl']

    IMAGE_COUNT.each do |count|
      send(:has_one_attached, "image_#{count}".to_sym)

      IMAGE_SIZE.each do |size|
        define_method("img_#{count}_#{size}") do |dimensions = nil|
          return if !send("image_#{count}").attached? || dimensions.nil?

          send("image_#{count}").variant(resize: dimensions)
        end
      end
    end

    belongs_to :linked_resource, polymorphic: true

    default_scope { order(position: :asc) }

    validates :name, :cms_page, :type, presence: true

    validates :image_one, :image_two, :image_three, content_type: IMAGE_TYPES

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

    private

    def reset_link_attributes
      if linked_resource_type_changed?
        return if linked_resource_id_was.nil?

        self.linked_resource_id = nil
      end
    end
  end
end

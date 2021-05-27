module Spree
  class CmsPage < Spree::Base
    PAGE_TYPES = ['Spree::Cms::Pages::StandardPage', 'Spree::Cms::Pages::FeaturePage', 'Spree::Cms::Pages::Homepage']

    extend FriendlyId
    friendly_id :slug, use: [:slugged, :finders, :history]

    belongs_to :store, touch: true
    has_many :cms_sections
    has_many :menu_items, as: :linked_resource

    before_validation :create_slug

    validates :title, presence: true

    scope :visible, -> { where visible: true }
    scope :by_store, ->(store) { where(store: store) }

    def seo_title
      if meta_title.present?
        meta_title
      else
        title
      end
    end

    def home_page(store, locale)
      find_by(store: store, locale: locale.to_s, type: 'Spree::Cms::Pages::Homepage') ||
        find_by(store: store, type: 'Spree::Cms::Pages::Homepage')
    end

    def sections?
      false
    end

    private

    def home_page?
      type == 'Spree::Cms::Pages::Homepage'
    end

    def create_slug
      self.slug = if slug.blank?
                    title.to_url
                  else
                    slug.to_url
                  end
    end
  end
end

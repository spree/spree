module Spree
  class CmsPage < Spree::Base
    PAGE_TYPES = ['Spree::Cms::Pages::StandardPage',
                  'Spree::Cms::Pages::FeaturePage',
                  'Spree::Cms::Pages::Homepage']

    extend FriendlyId
    friendly_id :slug, use: [:slugged, :finders, :history]

    belongs_to :store, touch: true
    has_many :cms_sections, dependent: :destroy

    has_many :menu_items, as: :linked_resource

    before_validation :handle_slug

    validates :title, presence: true

    scope :visible, -> { where visible: true }
    scope :by_store, ->(store) { where(store: store) }
    scope :by_locale, ->(locale) { where(locale: locale) }

    def seo_title
      if meta_title.present?
        meta_title
      else
        title
      end
    end

    # Overide this if your page uses cms_sections
    def sections?
      false
    end

    def homepage?
      type == 'Spree::Cms::Pages::Homepage'
    end

    def viewable?
      visible
    end

    def draft_mode?
      !visible
    end

    private

    def handle_slug
      return if homepage?

      self.slug = if slug.blank?
                    title.to_url
                  else
                    slug.to_url
                  end
    end
  end
end

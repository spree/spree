module Spree
  class CmsPage < Spree::Base
    PAGE_KINDS = ['Standard Page', 'Feature Page', 'Home Page']

    extend FriendlyId
    friendly_id :slug, use: [:slugged, :finders, :history]

    belongs_to :store, touch: true
    has_many :cms_sections
    has_many :menu_items, as: :linked_resource

    before_validation :create_slug

    validates :title, presence: true
    validates :slug, uniqueness: true
    validates :kind, uniqueness: { scope: [:store, :locale] }, if: :home_page?

    scope :visible, -> { where visible: true }
    scope :by_store, ->(store) { where(store: store) }

    def seo_title
      if meta_title.present?
        meta_title
      else
        title
      end
    end

    def self.by_localized_slug(slug, locale)
      find_by(slug: slug, locale: locale.to_s) || store.default_page
    end

    private

    def home_page?
      kind == 'Home Page'
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

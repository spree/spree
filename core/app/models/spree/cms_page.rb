module Spree
  class CmsPage < Spree::Base
    PAGE_KINDS = ['Standard Page','Feature Page', 'Home Page']

    extend FriendlyId
    friendly_id :slug, use: [:slugged, :finders, :history]

    belongs_to :store, touch: true
    has_many :cms_sections
    has_many :menu_items, as: :linked_resource

    before_save :create_slug

    validates :title, presence: true

    def seo_title
      if meta_title.present?
        meta_title
      else
        title
      end
    end

    private

    def create_slug
      self.slug = if slug.blank?
        title.to_url
      else
        slug.to_url
      end
    end
  end
end

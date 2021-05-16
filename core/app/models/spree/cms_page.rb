module Spree
  class CmsPage < Spree::Base
    PAGE_KINDS = ['Standard Page','Feature Page', 'Home Page']

    extend FriendlyId
    friendly_id :slug, use: [:slugged, :finders, :history]

    belongs_to :store, touch: true
    has_many :cms_sections
    has_many :menu_items, as: :linked_resource

    after_save :sync_menu_item_paths
    after_commit :sync_menu_item_paths

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

    def sync_menu_item_paths
      return unless saved_change_to_slug?

      Spree::MenuItem.refresh_paths(self)
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

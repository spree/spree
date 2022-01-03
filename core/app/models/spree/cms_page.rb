module Spree
  class CmsPage < Base
    include SingleStoreResource
    include DisplayLink

    if defined?(Spree::Webhooks)
      include Spree::Webhooks::HasWebhooks
    end

    acts_as_paranoid

    TYPES = ['Spree::Cms::Pages::StandardPage',
             'Spree::Cms::Pages::FeaturePage',
             'Spree::Cms::Pages::Homepage']

    belongs_to :store, touch: true

    has_many :cms_sections, class_name: 'Spree::CmsSection'
    has_many :menu_items, as: :linked_resource

    before_validation :handle_slug

    validates :title, :store, :locale, :type, presence: true
    validates :slug, uniqueness: { scope: :store_id, allow_nil: true, case_sensitive: true }
    validates :locale, uniqueness: { scope: [:store, :type] }, if: :homepage?

    scope :visible, -> { where(visible: true) }
    scope :by_locale, ->(locale) { where(locale: locale) }
    scope :by_slug, ->(slug) { where(slug: slug) }

    scope :home, -> { where(type: 'Spree::Cms::Pages::Homepage') }
    scope :standard, -> { where(type: 'Spree::Cms::Pages::StandardPage') }
    scope :feature, -> { where(type: 'Spree::Cms::Pages::FeaturePage') }

    self.whitelisted_ransackable_attributes = %w[title type locale]

    def seo_title
      if meta_title.present?
        meta_title
      else
        title
      end
    end

    # Override this if your page type uses cms_sections
    def sections?
      false
    end

    def homepage?
      type == 'Spree::Cms::Pages::Homepage'
    end

    def draft_mode?
      !visible
    end

    private

    def handle_slug
      self.slug = if homepage?
                    nil
                  elsif slug.blank?
                    title&.downcase&.to_url
                  else
                    slug&.downcase&.to_url
                  end
    end
  end
end

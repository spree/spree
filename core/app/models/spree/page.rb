module Spree
  class Page < Spree.base_class
    include Spree::Previewable
    include Spree::Linkable

    #
    # Magic methods
    #
    extend FriendlyId
    friendly_id :slug_candidates, use: [:slugged, :scoped, :history], scope: :pageable
    acts_as_paranoid

    #
    # Associations
    #
    belongs_to :pageable, polymorphic: true # this can be either Store or Theme
    has_many :sections, -> { order(position: :asc) }, class_name: 'Spree::PageSection', dependent: :destroy_async, as: :pageable
    alias page_sections sections

    #
    # Validations
    #
    validates :name, presence: true
    validates :pageable, presence: true
    validates :slug, uniqueness: { scope: :pageable, conditions: -> { where(deleted_at: nil).where.not(slug: nil) } }

    #
    # Callbacks
    #
    before_validation :set_name
    after_create :create_default_sections, unless: :duplicating

    #
    # Scopes
    #
    scope :linkable, lambda {
                        where(type: [
                                'Spree::Pages::Homepage',
                                'Spree::Pages::ShopAll',
                                'Spree::Pages::PostList',
                                'Spree::Pages::Custom',
                                'Spree::Pages::Account',
                                'Spree::Pages::Login'
                              ])
                     }
    scope :product_details, -> { where(type: 'Spree::Pages::ProductDetails') }
    scope :standard, -> { where.not(type: 'Spree::Pages::Custom') }
    scope :custom, -> { where(type: 'Spree::Pages::Custom') }

    #
    # Virtual attributes
    #
    attribute :duplicating, :boolean, default: false

    def icon_name
      'file-earmark-richtext'
    end

    def store
      if pageable.is_a?(Spree::Store)
        pageable
      else
        pageable.store
      end
    end

    def create_preview
      return self if preview? # no need to create a preview for the preview

      ActiveRecord::Base.connected_to(role: :writing) do
        ApplicationRecord.transaction do
          new_preview = dup
          new_preview.parent = self
          new_preview.duplicating = true
          new_preview.save!

          sections.includes(:links, { asset_attachment: :blob }, { blocks: [:rich_text_text, :links] }).each do |section|
            section.deep_clone(new_preview)
          end

          new_preview
        end
      end
    end

    # Promotes the page preview to the main page
    def promote
      return unless preview?

      ApplicationRecord.transaction do
        old_page = parent
        old_page.page_links.update_all(linkable_id: id)
        update(parent: nil) # clear reference to the old page
        Spree::Page.find(old_page.id).destroy # destroy the old page with their other previews, etc.
      end
    end

    def default_sections
      []
    end

    def customizable?
      false
    end

    def linkable?
      false
    end

    def layout_sections?
      true
    end

    def preview_url(theme_preview = nil, page_preview = nil)
      return if page_builder_url.blank?

      "#{page_builder_url}?#{url_query_params(theme_preview, page_preview).to_query}"
    end

    def display_name
      if custom?
        name
      else
        name.titleize
      end
    end

    def custom?
      type == 'Spree::Pages::Custom'
    end

    def duplicate(target_pageable)
      duplicated_page = dup
      duplicated_page.duplicating = true
      duplicated_page.pageable = target_pageable
      duplicated_page.save!

      sections_scope = sections.includes(:links, :blocks, { asset_attachment: :blob },
                                         { blocks: [:rich_text_text, :links, { asset_attachment: :blob }] })
      sections_scope.each { |section| section.deep_clone(duplicated_page) }

      duplicated_page
    end

    def theme
      @theme ||= if pageable.is_a?(Spree::Theme)
                   pageable
                 else
                   pageable.default_theme
                 end
    end

    private

    def create_default_sections
      default_sections.each do |section|
        section.pageable = self
        section.save!
      end
    end

    def url_query_params(theme_preview, page_preview)
      theme_preview_cache = theme_preview.updated_at.to_i.to_s + rand(999_999).to_s if theme_preview

      {
        theme_id: theme.id,
        page_preview_id: page_preview&.id,
        theme_preview_id: theme_preview&.id,
        theme_preview_cache: theme_preview_cache
      }
    end

    def set_name
      return if custom?
      return if name.present?

      self.name = self.class.name.demodulize
    end

    def should_generate_new_friendly_id?
      name_changed? && custom?
    end

    def page_builder_url_exists?(path)
      Spree::Core::Engine.routes.url_helpers.respond_to?(path)
    end
  end
end

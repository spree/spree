module Spree
  class Theme < Spree.base_class
    include Spree::SingleStoreResource
    include Spree::Previewable

    #
    # Magic methods
    #
    acts_as_paranoid

    #
    # Validations
    #
    validates :name, :store, presence: true

    #
    # Associations
    #
    belongs_to :store, class_name: 'Spree::Store', touch: true
    belongs_to :parent, class_name: 'Spree::Theme', optional: true, foreign_key: :parent_id
    has_many :previews, class_name: 'Spree::Theme', foreign_key: :parent_id, dependent: :destroy_async
    has_many :pages, -> { without_previews }, class_name: 'Spree::Page', dependent: :destroy, as: :pageable
    has_many :page_previews, -> { only_previews }, class_name: 'Spree::Page', dependent: :destroy_async, as: :pageable
    has_many :layout_sections, -> { order(position: :asc) }, class_name: 'Spree::PageSection', dependent: :destroy, as: :pageable
    alias sections layout_sections

    #
    # Attachments
    #
    has_one_attached :screenshot, service: Spree.public_storage_service_name

    #
    #
    # Callbacks
    #
    before_validation :set_name, on: :create
    before_save :ensure_default_exists_and_is_unique
    after_create :create_default_pages, :create_layout_sections, unless: :duplicating?
    before_destroy :change_name_to_archived

    #
    # Virtual attributes
    #
    attribute :duplicating, :boolean, default: false

    #
    # Class methods
    #
    def self.to_param
      Spree::Theme.to_s
    end

    # Returns an array of available themes, sorted by display name
    #
    # We need to load the theme classes to get the display name, so we also load the page classes at the same time
    #
    # @return [Array<Spree::Theme>]
    def self.available_themes
      @available_themes ||= Spree.page_builder.themes.sort_by(&:display_name)
    end

    def self.metadata
      {
        authors: [], # eg. ['Spree Commerce']
        website: '', # eg. 'https://spreecommerce.org'
        license: '', # eg. 'MIT', https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/licensing-a-repository#searching-github-by-license-type
        description: '', # eg. 'A theme for Spree Commerce'
        preview_image_url: '' # eg. 'https://example.com/screenshot.png'
      }
    end

    def self.display_name
      metadata[:name].presence || name.demodulize.titleize
    end

    def self.authors
      metadata[:authors]
    end

    def self.license
      metadata[:license]
    end

    def self.description
      metadata[:description]
    end

    def self.preview_image_url
      metadata[:preview_image_url]
    end

    def self.website
      metadata[:website]
    end

    def duplicate
      Themes::Duplicator.new(self).duplicate
    end

    def create_default_pages
      Spree.page_builder.pages.map(&:to_s).map(&:constantize).each do |page_class|
        next if page_class == Spree::Pages::Custom

        page_class.where(pageable: self).first_or_create!
      end
    end

    def create_layout_sections
      ApplicationRecord.transaction do
        available_layout_sections.map(&:to_s).map(&:constantize).each do |section_class|
          section_class.where(pageable: self).first_or_create!
        end
      end
    end

    # Creates a new preview for the theme
    #
    # @return [Spree::Theme]
    def create_preview
      ActiveRecord::Base.connected_to(role: :writing) do
        ApplicationRecord.transaction do
          new_preview = dup
          new_preview.parent = self
          new_preview.duplicating = true
          new_preview.default = false

          # we need to deep clone layout sections and their assets
          sections.includes(:links, { asset_attachment: :blob }, { blocks: [:rich_text_text, :links] }).each do |section|
            section.deep_clone(new_preview)
          end

          new_preview.save!
          new_preview
        end
      end
    end

    # Promotes the preview to the main theme
    def promote
      return unless preview?

      ApplicationRecord.transaction do
        old_theme = parent

        # clear reference to the old theme and set default to the old theme's default
        update!(parent: nil, default: old_theme.default)

        # move pages to the new theme
        old_theme.pages.update_all(pageable_id: id)

        # destroy the old theme with their other previews, etc.
        store.themes.find(old_theme.id).destroy

        take_screenshot # update the screenshot
      end
    end

    # Returns an array of available layout section classes for the theme, eg. header, footer, newsletter, etc.
    #
    # @return [Array<Class>]
    def available_layout_sections
      [
        *Spree.page_builder.theme_layout_sections,
        *custom_layout_sections
      ]
    end

    # Returns an array of custom layout section classes for the theme
    #
    # @return [Array<Class>]
    def custom_layout_sections
      # you can override this method in your theme to return a list of custom layout sections for your theme
      # [Spree::PageSections::Custom, Spree::PageSections::Custom2]
      []
    end

    # Returns an array of available page section classes for the theme
    #
    # @return [Array<Class>]
    def available_page_sections
      return @available_page_sections if @available_page_sections

      @available_page_sections ||= [
        *Spree.page_builder.page_sections.find_all do |section_class|
          section_class.role == 'content'
        end,
        *custom_page_sections
      ].sort_by(&:name)
    end

    # Returns an array of custom page section classes for the theme
    #
    # @return [Array<Class>]
    def custom_page_sections
      # you can override this method in your theme to return a list of custom page sections for your theme
      # [Spree::PageSections::Custom, Spree::PageSections::Custom2]
      []
    end

    def restore_defaults!
      self.preferences = {}
      save!
    end

    def take_screenshot
      return if Spree.screenshot_api_token.blank?
      return if preview? # we don't want to take screenshots of previews, they aren't surfaced in the UI
      return if screenshot.attached?

      Spree::Themes::ScreenshotJob.perform_later(id)
    end

    protected

    def set_name
      self.name = type.demodulize.titleize if name.blank?
    end

    private

    def ensure_default_exists_and_is_unique
      if default
        store.themes.where.not(id: id).update_all(default: false, updated_at: Time.current)
      elsif store.themes.where(default: true).count.zero?
        self.default = true
      end
    end

    def change_name_to_archived
      update_columns(name: "#{name} (Archived)")
    end
  end
end

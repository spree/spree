module Spree
  class PageSection < Spree.base_class
    include Spree::HasPageLinks
    #
    # Magic methods
    #
    acts_as_paranoid
    acts_as_list scope: [:pageable_id, { deleted_at: nil }]

    #
    # Associations
    #
    belongs_to :pageable, polymorphic: true, touch: true # this can be either Page or Theme
    has_many :blocks, lambda {
                        order(position: :asc)
                      }, class_name: 'Spree::PageBlock', dependent: :destroy, inverse_of: :section, foreign_key: :section_id
    alias page_blocks blocks
    delegate :store, to: :pageable

    #
    # Attachments
    #
    has_one_attached :asset, service: Spree.public_storage_service_name
    alias image asset

    #
    # Rich Text
    #
    has_rich_text :text
    has_rich_text :description

    #
    # Validations
    #
    validates :name, :pageable, presence: true
    validates :asset, content_type: Rails.application.config.active_storage.web_image_content_types

    #
    # Callbacks
    #
    before_validation :set_name, on: :create
    after_create :create_blocks, unless: :do_not_create_blocks

    #
    # Scopes
    #
    scope :published, -> { where(pageable_type: 'Spree::Page') }
    scope :related_products, -> { where(type: 'Spree::PageSections::RelatedProducts') }

    #
    # Preferences
    #
    TEXT_COLOR_DEFAULT = nil
    BACKGROUND_COLOR_DEFAULT = nil
    BORDER_COLOR_DEFAULT = nil
    TOP_PADDING_DEFAULT = 40
    BOTTOM_PADDING_DEFAULT = 40
    TOP_BORDER_WIDTH_DEFAULT = 1
    BOTTOM_BORDER_WIDTH_DEFAULT = 0

    preference :text_color, :string, default: -> { self.class::TEXT_COLOR_DEFAULT if defined?(self.class::TEXT_COLOR_DEFAULT) }
    preference :background_color, :string, default: -> { self.class::BACKGROUND_COLOR_DEFAULT if defined?(self.class::BACKGROUND_COLOR_DEFAULT) }
    preference :border_color, :string, default: -> { self.class::BORDER_COLOR_DEFAULT if defined?(self.class::BORDER_COLOR_DEFAULT) }
    preference :top_padding, :integer, default: -> { self.class::TOP_PADDING_DEFAULT if defined?(self.class::TOP_PADDING_DEFAULT) }
    preference :bottom_padding, :integer, default: -> { self.class::BOTTOM_PADDING_DEFAULT if defined?(self.class::BOTTOM_PADDING_DEFAULT) }
    preference :top_border_width, :integer, default: -> { self.class::TOP_BORDER_WIDTH_DEFAULT if defined?(self.class::TOP_BORDER_WIDTH_DEFAULT) }
    preference :bottom_border_width, :integer, default: -> { self.class::BOTTOM_BORDER_WIDTH_DEFAULT if defined?(self.class::BOTTOM_BORDER_WIDTH_DEFAULT) }

    #
    # Virtual attributes
    #
    attribute :do_not_create_blocks, :boolean, default: false
    attr_accessor :default_blocks

    def to_partial_path
      "spree/page_sections/#{type.to_s.demodulize.underscore}"
    end

    # this should be overridden in subclasses
    def default_blocks
      @default_blocks.presence || []
    end

    def blocks_available?
      false
    end

    def available_blocks_to_add
      []
    end

    def can_sort_blocks?
      false
    end

    # this should be overridden in subclasses
    # content - can be managed by the user
    # system - main parts of the page eg. product details, login form
    # header - header section
    # footer - footer section
    def self.role
      'content'
    end

    def role
      self.class.role
    end

    def theme
      @theme ||= if pageable.is_a?(Spree::Theme)
                   pageable
                 else
                   pageable.theme
                 end
    end

    def icon_name
      'text-caption'
    end

    def can_be_deleted?
      role == 'content'
    end

    def can_be_sorted?
      true
    end

    def lazy?
      false
    end

    def lazy_path(variables)
      url_options = variables[:url_options] || {}

      Spree::Core::Engine.routes.url_helpers.page_section_path(self, **url_options)
    end

    def rich_text_fields
      self.class.rich_text_association_names.map { |rt| rt.to_s.sub('rich_text_', '') }
    end

    def copy_rich_text_fields_from(other)
      rich_text_fields.each do |field|
        send(field).body = other.send(field).body
      end
    end

    def deep_clone(target)
      new_section = type.constantize.new(
        preferences: preferences,
        position: position,
        pageable: target
      )
      new_section.copy_rich_text_fields_from(self)
      new_section.do_not_create_blocks = true
      new_section.do_not_create_links = true
      new_section.save!

      new_section.asset.attach(asset.blob) if asset.attached?

      blocks.includes(:links, asset_attachment: :blob).each do |block|
        new_block = block.type.constantize.new(
          preferences: block.preferences,
          position: block.position,
          section: new_section
        )
        new_block.do_not_create_links = true
        new_block.text = block.text if block.respond_to?(:text) # we need to copy ActionText content
        new_block.save!

        new_block.asset.attach(block.asset.blob) if block.asset.attached?

        deep_clone_links(block, new_block)
      end

      deep_clone_links(self, new_section)
    end

    def deep_clone_links(section_or_block, new_section_or_block)
      section_or_block.links.each do |link|
        new_link = link.dup
        new_link.parent = new_section_or_block
        new_link.save!
      end
    end

    # Turns out #dup doesn't not copy rich text content to the new record.
    # https://github.com/rails/rails/issues/36683
    def dup
      super.tap do |object|
        object.copy_rich_text_fields_from(self)
      end
    end

    def restore_design_settings_to_defaults
      restore_preferences_for(design_settings_to_restore)
      save
    end

    def display_name
      name
    end

    private

    def design_settings_to_restore
      [:text_color, :background_color, :border_color, :top_padding, :bottom_padding, :top_border_width, :bottom_border_width]
    end

    def create_blocks
      default_blocks.each do |block|
        block.section = self
        block.save!
      end
    end

    def set_name
      self.name ||= type.to_s.demodulize.titleize
    end
  end
end

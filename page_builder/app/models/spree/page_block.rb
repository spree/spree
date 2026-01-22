module Spree
  class PageBlock < Spree.base_class
    include Spree::HasPageLinks

    #
    # Magic methods
    #
    acts_as_paranoid
    acts_as_list scope: :section

    #
    # Associations
    #
    belongs_to :section, class_name: 'Spree::PageSection', inverse_of: :blocks, touch: true
    delegate :store, :theme, to: :section

    #
    # Rich Text
    #
    has_rich_text :text

    #
    # Attachments
    #
    has_one_attached :asset, service: Spree.public_storage_service_name

    #
    # Validations
    #
    validates :section, :type, :name, presence: true
    validates :asset, content_type: Rails.application.config.active_storage.web_image_content_types

    #
    # Callbacks
    #
    before_validation :set_name_from_type, on: :create

    #
    # Preferences
    #
    TEXT_ALIGNMENT_DEFAULT = 'left'
    CONTAINER_ALIGNMENT_DEFAULT = 'left'
    SIZE_DEFAULT = 'medium'
    WIDTH_DESKTOP_DEFAULT = 100
    TOP_PADDING_DEFAULT = 0
    BOTTOM_PADDING_DEFAULT = 0

    preference :text_alignment, :string, default: -> { self.class::TEXT_ALIGNMENT_DEFAULT if defined?(self.class::TEXT_ALIGNMENT_DEFAULT) }
    preference :container_alignment, :string, default: -> { self.class::CONTAINER_ALIGNMENT_DEFAULT if defined?(self.class::CONTAINER_ALIGNMENT_DEFAULT) }
    preference :size, :string, default: -> { self.class::SIZE_DEFAULT if defined?(self.class::SIZE_DEFAULT) }
    preference :width_desktop, :integer, default: -> { self.class::WIDTH_DESKTOP_DEFAULT if defined?(self.class::WIDTH_DESKTOP_DEFAULT) }
    preference :top_padding, :integer, default: -> { self.class::TOP_PADDING_DEFAULT if defined?(self.class::TOP_PADDING_DEFAULT) }
    preference :bottom_padding, :integer, default: -> { self.class::BOTTOM_PADDING_DEFAULT if defined?(self.class::BOTTOM_PADDING_DEFAULT) }

    def display_name
      name
    end

    def form_partial_name
      type.demodulize.underscore
    end

    def icon_name
      'fullscreen'
    end

    private

    def set_name_from_type
      self.name ||= type.demodulize.titleize
    end
  end
end

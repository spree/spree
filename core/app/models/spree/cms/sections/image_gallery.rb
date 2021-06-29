module Spree::Cms::Sections
  class ImageGallery < Spree::CmsSection
    after_initialize :default_values

    LINKED_RESOURCE_TYPE = ['Spree::Taxon', 'Spree::Product'].freeze
    LAYOUT_OPTIONS = ['Default', 'Reversed'].freeze
    LABEL_OPTIONS = ['Show', 'Hide'].freeze

    store :content, accessors: [:link_type_one, :link_one, :title_one,
                                :link_type_two, :link_two, :title_two,
                                :link_type_three, :link_three, :title_three], coder: JSON

    store :settings, accessors: [:layout_style, :display_labels], coder: JSON

    def default_layout?
      layout_style == 'Default'
    end

    def show_labels?
      display_labels == 'Show'
    end

    private

    def default_values
      self.layout_style ||= 'Default'
      self.fit ||= 'Container'
      self.link_type_one ||= 'Spree::Taxon'
      self.link_type_two ||= 'Spree::Taxon'
      self.link_type_three ||= 'Spree::Taxon'
    end
  end
end

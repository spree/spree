module Spree::Cms::Sections
  class ImageGallery < Spree::CmsSection
    after_initialize :default_values
    validate :reset_multiple_link_attributes

    LINKED_RESOURCE_TYPE = if Rails::VERSION::STRING < '6.0'
                             ['Spree::Taxon'].freeze
                           else
                             ['Spree::Taxon', 'Spree::Product'].freeze
                           end

    LAYOUT_OPTIONS = ['Default', 'Reversed'].freeze
    LABEL_OPTIONS = ['Show', 'Hide'].freeze

    store :content, accessors: [:link_type_one, :link_one, :title_one,
                                :link_type_two, :link_two, :title_two,
                                :link_type_three, :link_three, :title_three], coder: JSON

    store :settings, accessors: [:layout_style, :display_labels], coder: JSON

    #
    # img_one sizing
    def img_one_md(dimensions = '270x195>')
      super
    end

    def img_one_lg(dimensions = '540x390>')
      super
    end

    def img_one_xl(dimensions = '1080x780>')
      super
    end

    #
    # img_two sizing
    def img_two_md(dimensions = '270x400>')
      super
    end

    def img_two_lg(dimensions = '540x800>')
      super
    end

    def img_two_xl(dimensions = '1080x1600>')
      super
    end

    #
    # img_three sizing
    def img_three_md(dimensions = '270x195>')
      super
    end

    def img_three_lg(dimensions = '540x390>')
      super
    end

    def img_three_xl(dimensions = '1080x780>')
      super
    end

    def default_layout?
      layout_style == 'Default'
    end

    def show_labels?
      display_labels == 'Show'
    end

    private

    def reset_multiple_link_attributes
      return if Rails::VERSION::STRING < '6.0'

      if link_type_one_changed?
        return if link_type_one_was.nil?

        self.link_one = nil
      end

      if link_type_two_changed?
        return if link_type_two_was.nil?

        self.link_two = nil
      end

      if link_type_three_changed?
        return if link_type_three_was.nil?

        self.link_three = nil
      end
    end

    def default_values
      self.layout_style ||= 'Default'
      self.fit ||= 'Container'
      self.link_type_one ||= 'Spree::Taxon'
      self.link_type_two ||= 'Spree::Taxon'
      self.link_type_three ||= 'Spree::Taxon'
    end
  end
end

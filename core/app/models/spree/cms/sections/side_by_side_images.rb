module Spree::Cms::Sections
  class SideBySideImages < Spree::CmsSection
    after_initialize :default_values
    before_save :reset_link_attributes

    LINKED_RESOURCE_TYPE = ['Spree::Taxon', 'Spree::Product'].freeze

    store :content, accessors: [:link_type_one, :link_one, :title_one, :subtitle_one,
                                :link_type_two, :link_two, :title_two, :subtitle_two], coder: JSON

    store :settings, accessors: [:gutters], coder: JSON

    def gutters?
      gutters == 'Gutters'
    end

    private

    def reset_link_attributes
      return if Rails::VERSION::STRING < '6.0'

      if link_type_one_changed?
        self.link_one = nil
      end

      if link_type_two_changed?
        self.link_two = nil
      end
    end

    def default_values
      self.gutters ||= 'Gutters'
      self.fit ||= 'Container'
      self.link_type_one ||= 'Spree::Taxon'
      self.link_type_two ||= 'Spree::Taxon'
    end
  end
end

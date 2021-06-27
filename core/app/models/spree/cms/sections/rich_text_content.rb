module Spree::Cms::Sections
  class RichTextContent < Spree::CmsSection
    after_initialize :default_values

    store :content, accessors: [:rte_content], coder: JSON
    store :settings, accessors: [:gutters], coder: JSON

    def gutters?
      gutters == 'Gutters'
    end

    private

    def default_values
      self.gutters ||= 'Gutters'
      self.fit ||= 'Container'
    end
  end
end

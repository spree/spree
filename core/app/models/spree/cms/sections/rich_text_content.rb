module Spree::Cms::Sections
  class RichTextContent < Spree::CmsSection
    after_initialize :default_values

    store :content, accessors: [:rte_content], coder: JSON

    private

    def default_values
      self.fit ||= 'Container'
    end
  end
end

module Spree::Cms::Sections
  class ProductBuyBar < Spree::CmsSection
    after_initialize :default_values

    store :content, accessors: [:overide_product_name, :button_text], coder: JSON
    store :settings, accessors: [:show_price], coder: JSON

    LINKED_RESOURCE_TYPE = ['Spree::Product']

    def css_classes
      ['row', 'section-row', 'sticky-top'].compact
    end

    private

    def default_values
      self.fit ||= 'Screen'
      self.linked_resource_type ||= 'Spree::Product'
    end
  end
end

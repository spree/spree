module Spree::Cms::Sections
  class HeroImage < Spree::CmsSection
    after_initialize :default_values

    store :content, accessors: [:title, :button_text], coder: JSON
    store :settings, accessors: [:gutters], coder: JSON

    LINKED_RESOURCE_TYPE = ['Spree::Taxon', 'Spree::Product', 'Spree::CmsPage']

    def gutters?
      gutters == 'Gutters'
    end

    def img_one_sm(dimensions = '600x250>')
      super
    end

    def img_one_md(dimensions = '1200x500>')
      super
    end

    def img_one_lg(dimensions = '2400x1000>')
      super
    end

    def img_one_xl(dimensions = '4800x2000>')
      super
    end

    private

    def default_values
      self.gutters ||= 'No Gutters'
      self.fit ||= 'Screen'
      self.linked_resource_type ||= 'Spree::Taxon'
    end
  end
end

module Spree::Cms::Sections
  class StaticBrandingBar < Spree::CmsSection
    after_initialize :default_values

    store :content, accessors: [:title, :subtitle], coder: JSON

    private

    def default_values
      self.fit ||= 'Screen'
    end
  end
end

module Spree::Cms::Sections
  class StaticBrandingBar < Spree::CmsSection
    after_initialize :default_values

    store :options, accessors: [:title, :subtitle], coder: JSON

    def widths
      ['Full']
    end

    private

    def default_values
      self.width ||= 'Full'
      self.fit ||= 'Screen'
    end
  end
end

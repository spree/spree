module Spree::Cms::Sections
  class MenuCategory < Spree::CmsSection
    after_initialize :default_values

    def widths
      ['Full']
    end

    private

    def default_values
      self.width ||= 'Full'
    end
  end
end

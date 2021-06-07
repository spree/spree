module Spree::Cms::Sections
  class Brands < Spree::CmsSection
    after_initialize :default_values

    def widths
      ['Full']
    end

    private

    def default_values
      self.width ||= 'Full'
      self.boundary ||= 'Screen'
    end
  end
end

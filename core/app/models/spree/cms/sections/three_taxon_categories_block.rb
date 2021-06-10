module Spree::Cms::Sections
  class ThreeTaxonCategoriesBlock < Spree::CmsSection
    after_initialize :default_values

    has_one_attached :image_one
    has_one_attached :image_two
    has_one_attached :image_three

    def widths
      ['Full']
    end

    private

    def default_values
      self.width ||= 'Full'
    end
  end
end

module Spree::Cms::Sections
  class ThreeTaxonCategoriesBlock < Spree::CmsSection
    after_initialize :default_values

    store :options, accessors: [:permalink_one, :title_one,
                                :permalink_two, :title_two,
                                :permalink_three, :title_three], coder: JSON

    def widths
      ['Full']
    end

    private

    def default_values
      self.width ||= 'Full'
    end
  end
end

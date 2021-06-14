module Spree::Cms::Sections
  class ThreeTaxonCategoriesBlock < Spree::CmsSection
    after_initialize :default_values

    store :content, accessors: [:permalink_one, :title_one,
                                :permalink_two, :title_two,
                                :permalink_three, :title_three], coder: JSON

    private

    def default_values
      self.fit ||= 'Container'
    end
  end
end

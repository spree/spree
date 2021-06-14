module Spree::Cms::Sections
  class SideBySidePromotion < Spree::CmsSection
    after_initialize :default_values

    store :content, accessors: [:permalink_one, :title_one, :subtitle_one,
                                :permalink_two, :title_two, :subtitle_two], coder: JSON
    store :settings, accessors: [:gutters], coder: JSON

    def gutters?
      gutters == 'Gutters'
    end

    private

    def default_values
      self.gutters ||= 'Gutters'
      self.fit ||= 'Container'
    end
  end
end

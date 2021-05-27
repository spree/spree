module Spree::Cms::Pages
  class FeaturePage < Spree::CmsPage
    validates :slug, uniqueness: true

    def sections?
      true
    end
  end
end

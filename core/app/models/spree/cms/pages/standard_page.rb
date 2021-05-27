module Spree::Cms::Pages
  class StandardPage < Spree::CmsPage
    validates :slug, uniqueness: true

    def sections?
      false
    end
  end
end

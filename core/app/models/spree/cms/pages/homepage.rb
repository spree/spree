module Spree::Cms::Pages
  class Homepage < Spree::CmsPage
    before_create :empty_slug
    after_save :empty_slug

    def sections?
      true
    end

    def seo_meta_description
      meta_description if meta_description.present?
    end

    private

    def empty_slug
      self.slug = nil
    end
  end
end

module Spree::Cms::Pages
  class Homepage < Spree::CmsPage
    before_create :empty_slug
    after_save :empty_slug

    validates :type, uniqueness: { scope: [:store, :locale] }

    def sections?
      true
    end

    private

    def empty_slug
      self.slug = nil
    end
  end
end

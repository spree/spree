module Spree::Cms::Pages
  class Homepage < Spree::CmsPage
    validates :type, uniqueness: { scope: [:store, :locale] }

    def sections?
      false
    end

    private

    def create_slug
      self.slug = nil
    end
  end
end

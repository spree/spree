module Spree::Cms::Pages
  class Homepage < Spree::CmsPage
    validates :type, uniqueness: { scope: [:store, :locale] }

    def sections?
      true
    end

    private

    def handle_slug
      self.slug = nil
    end
  end
end

module Spree
  module V2
    module Storefront
      class CmsPageSerializer < BaseSerializer
        set_type :cms_page

        attributes :title, :content, :locale, :meta_description, :meta_title,
                   :slug, :type

        belongs_to :store
        has_many :cms_sections
      end
    end
  end
end

module Spree
  module V2
    module Storefront
      class CmsPageSerializer < BaseSerializer
        set_type :cms_page

        attributes :title, :content, :locale, :meta_description, :meta_title,
                   :slug, :type

        has_many :cms_sections, serializer: :cms_section
      end
    end
  end
end

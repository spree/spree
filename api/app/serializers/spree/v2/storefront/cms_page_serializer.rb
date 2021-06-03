module Spree
  module V2
    module Storefront
      class CmsPageSerializer < BaseSerializer
        set_type :cms_page

        attributes :title, :type, :locale

      end
    end
  end
end

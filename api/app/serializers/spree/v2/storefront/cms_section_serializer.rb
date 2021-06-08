module Spree
  module V2
    module Storefront
      class CmsSectionSerializer < BaseSerializer
        set_type :cms_section

        attributes :name, :title, :subtitle, :button_text, :content, :width,
                   :full_width_on_small, :fit, :type, :position

        belongs_to :cms_page
      end
    end
  end
end

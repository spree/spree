module Spree
  module V2
    module Storefront
      class MenuSerializer < BaseSerializer
        set_type :menu

        attributes :name, :unique_code

        has_many :menu_items
      end
    end
  end
end

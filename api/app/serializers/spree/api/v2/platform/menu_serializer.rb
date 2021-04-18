module Spree
  module Api
    module V2
      module Platform
        class MenuSerializer < BaseSerializer
          include ::Spree::Api::V2::ResourceSerializerConcern

          has_many :menu_items
        end
      end
    end
  end
end

module Spree
  module Api
    module V2
      module Platform
        class MenuItemSerializer < BaseSerializer
          include ::Spree::Api::V2::ResourceSerializerConcern

          belongs_to :menu
        end
      end
    end
  end
end

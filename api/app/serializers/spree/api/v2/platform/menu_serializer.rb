module Spree
  module Api
    module V2
      module Platform
        class MenuSerializer < BaseSerializer
          include ::Spree::Api::V2::ResourceSerializerConcern

          belongs_to :store
          has_many :menu_items
        end
      end
    end
  end
end

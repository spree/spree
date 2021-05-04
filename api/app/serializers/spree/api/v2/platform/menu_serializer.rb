module Spree
  module Api
    module V2
      module Platform
        class MenuSerializer < BaseSerializer
          include ::Spree::Api::V2::ResourceSerializerConcern

          attributes :name, :unique_code

          belongs_to :store
          has_many :menu_items
        end
      end
    end
  end
end

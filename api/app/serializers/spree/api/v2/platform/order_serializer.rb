module Spree
  module Api
    module V2
      module Platform
        class OrderSerializer < BaseSerializer
          include ::Spree::Api::V2::ResourceSerializerConcern

          has_many :line_items
        end
      end
    end
  end
end

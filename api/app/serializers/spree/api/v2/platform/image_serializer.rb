module Spree
  module Api
    module V2
      module Platform
        class ImageSerializer < BaseSerializer
          include ::Spree::Api::V2::ResourceSerializerConcern

          attribute :styles
        end
      end
    end
  end
end

module Spree
  module Api
    module V2
      module Platform
        class ImageSerializer < BaseSerializer
          set_type :image

          attributes :viewable_type, :viewable_id, :styles
        end
      end
    end
  end
end

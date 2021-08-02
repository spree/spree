module Spree
  module Api
    module V2
      module Platform
        class ImageSerializer < BaseSerializer
          set_type :image

          attributes :styles, :position, :alt, :created_at, :updated_at

          belongs_to :viewable, polymorphic: true
        end
      end
    end
  end
end

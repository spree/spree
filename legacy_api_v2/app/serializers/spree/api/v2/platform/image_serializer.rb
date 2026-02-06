module Spree
  module Api
    module V2
      module Platform
        class ImageSerializer < BaseSerializer
          include ::Spree::Api::V2::ImageTransformationConcern

          set_type :image

          attributes :styles, :position, :alt, :created_at, :updated_at, :original_url

          belongs_to :viewable, polymorphic: true
        end
      end
    end
  end
end

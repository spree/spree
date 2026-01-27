module Spree
  module Api
    module V2
      module ImageTransformationConcern
        extend ActiveSupport::Concern

        def self.included(base)
          base.attribute :transformed_url do |image, params|
            image.generate_url(size: params.dig(:image_transformation, :size))
          end
        end
      end
    end
  end
end

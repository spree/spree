module Spree
  module Api
    module V2
      module TaxonImageTransformationConcern
        extend ActiveSupport::Concern

        def self.included(base)
          base.attribute :transformed_url do |image, params|
            image.generate_url(size: params.dig(:taxon_image_transformation, :size))
          end
        end
      end
    end
  end
end

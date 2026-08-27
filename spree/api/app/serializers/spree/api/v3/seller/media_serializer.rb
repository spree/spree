module Spree
  module Api
    module V3
      module Seller
        # A file on a seller's own product.
        #
        # Declared from the store base rather than the admin serializer, like
        # every serializer on this branch. What a seller needs is the file, how
        # it is cropped, and which variants it belongs to.
        class MediaSerializer < V3::MediaSerializer
          typelize position: :number,
                   variant_ids: [:string, multi: true],
                   focal_point_x: [:number, nullable: true],
                   focal_point_y: [:number, nullable: true]

          attributes :position, :focal_point_x, :focal_point_y,
                     created_at: :iso8601, updated_at: :iso8601

          attribute :variant_ids do |media|
            media.variants.map(&:prefixed_id)
          end
        end
      end
    end
  end
end

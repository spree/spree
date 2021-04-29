module Spree
  module Api
    module V2
      module Platform
        class TaxonImageSerializer < BaseSerializer
          set_type   :taxon_image

          attributes :viewable_type, :viewable_id, :styles
        end
      end
    end
  end
end

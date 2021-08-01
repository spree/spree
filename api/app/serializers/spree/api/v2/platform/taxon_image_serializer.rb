module Spree
  module Api
    module V2
      module Platform
        class TaxonImageSerializer < BaseSerializer
          set_type :taxon_image

          attributes :styles, :alt, :created_at, :updated_at
        end
      end
    end
  end
end

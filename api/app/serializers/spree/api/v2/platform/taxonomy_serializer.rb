module Spree
  module Api
    module V2
      module Platform
        class TaxonomySerializer < BaseSerializer
          set_type   :taxonomy

          attributes :name, :position
        end
      end
    end
  end
end

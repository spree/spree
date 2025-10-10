module Spree
  module Api
    module V2
      module Platform
        class AssetSerializer < BaseSerializer
          include ResourceSerializerConcern

          belongs_to :viewable, polymorphic: true
        end
      end
    end
  end
end

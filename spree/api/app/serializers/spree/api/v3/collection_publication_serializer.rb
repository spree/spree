module Spree
  module Api
    module V3
      class CollectionPublicationSerializer < PublicationSerializer
        typelize collection_id: :string

        prefixed_id_attributes :collection
      end
    end
  end
end

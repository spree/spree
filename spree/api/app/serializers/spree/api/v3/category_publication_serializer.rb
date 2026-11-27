module Spree
  module Api
    module V3
      class CategoryPublicationSerializer < PublicationSerializer
        typelize category_id: :string

        prefixed_id_attributes :category
      end
    end
  end
end

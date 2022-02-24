module Spree
  module Api
    module V2
      module Platform
        class StoreSerializer < BaseSerializer
          include ResourceSerializerConcern
          include StoreMediaSerializerImagesConcern

          has_many :menus
          has_one :default_country, serializer: :country, record_type: :country, id_method_name: :default_country_id
        end
      end
    end
  end
end

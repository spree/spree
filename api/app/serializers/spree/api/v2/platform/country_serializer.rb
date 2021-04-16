module Spree
  module Api
    module V2
      module Platform
        class CountrySerializer < BaseSerializer
          include ::Spree::Api::V2::ResourceSerializerConcern

          has_many :states
        end
      end
    end
  end
end

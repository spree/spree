module Spree
  module Api
    module V2
      module Platform
        class PrototypeSerializer < BaseSerializer
          include ResourceSerializerConcern

          has_many :properties
          has_many :option_types
          has_many :taxons
        end
      end
    end
  end
end

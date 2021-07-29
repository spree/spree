module Spree
  module Api
    module V2
      module ResourceSerializerConcern
        extend ActiveSupport::Concern

        def self.included(base)
          model_klazz = "Spree::#{base.to_s.demodulize.gsub(/Serializer/, '')}".constantize

          base.set_type model_klazz.json_api_type
          base.attributes(*model_klazz.json_api_columns)
        end
      end
    end
  end
end

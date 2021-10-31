module Spree
  module Api
    module V2
      module ResourceSerializerConcern
        extend ActiveSupport::Concern

        def self.included(base)
          serializer_base_name = base.to_s.sub(/^Spree::Api::V2::Platform::/, '').sub(/Serializer$/, '')
          model_klazz = "Spree::#{serializer_base_name}".constantize

          base.set_type model_klazz.json_api_type
          # include standard attributes
          base.attributes(*model_klazz.json_api_columns)
          # include money attributes
          base.attributes(*model_klazz.new.methods.find_all do |m|
            m.to_s.match(/display_/) && !m.to_s.match(/\=/) && !([Spree::Product, Spree::Variant].include?(model_klazz) && m == :display_amount)
          end)
        end
      end
    end
  end
end

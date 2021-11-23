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
          display_getter_methods(model_klazz).each do |method_name|
            base.attribute(method_name) do |object|
              object.public_send(method_name).to_s
            end
          end
        end

        def self.display_getter_methods(model_klazz)
          model_klazz.new.methods.find_all do |method_name|
            method_name.to_s.match(/display_/) && # if it's a display_ prefixed method, but
              !method_name.to_s.match(/\=/)    && # is not a setter method, and
              # display_amount but not for Spree::Product or Spree::Variants
              !([Spree::Product, Spree::Variant].include?(model_klazz) && method_name == :display_amount)
          end
        end
      end
    end
  end
end

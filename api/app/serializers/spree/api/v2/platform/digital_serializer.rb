module Spree
  module Api
    module V2
      module Platform
        class DigitalSerializer < BaseSerializer
          set_type :digital

          attribute :url do |digital|
            url_helpers.polymorphic_url(digital.attachment, only_path: true)
          end

          attribute :content_type do |digital|
            digital.attachment.content_type.to_s
          end

          attribute :filename do |digital|
            digital.attachment.filename.to_s
          end

          attribute :byte_size do |digital|
            digital.attachment.byte_size.to_i
          end

          belongs_to :variant, serializer: Spree::Api::Dependencies.platform_variant_serializer.constantize
        end
      end
    end
  end
end

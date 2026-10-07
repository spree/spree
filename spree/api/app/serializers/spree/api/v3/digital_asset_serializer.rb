# frozen_string_literal: true

module Spree
  module Api
    module V3
      class DigitalAssetSerializer < BaseSerializer
        typelize variant_id: [:string, nullable: true],
                 filename: [:string, nullable: true],
                 content_type: [:string, nullable: true]

        prefixed_id_attributes :variant

        attribute :filename do |digital_asset|
          digital_asset.filename&.to_s
        end

        attributes :content_type
      end
    end
  end
end

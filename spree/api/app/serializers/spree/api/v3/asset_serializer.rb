# frozen_string_literal: true

module Spree
  module Api
    module V3
      class AssetSerializer < BaseSerializer
        typelize type: [:string, nullable: true], viewable_type: :string,
                 viewable_id: :string, position: [:number, nullable: true],
                 alt: [:string, nullable: true]

        attribute :viewable_id do |asset|
          asset.viewable&.prefixed_id
        end

        attributes :type, :viewable_type, :position, :alt,
                   created_at: :iso8601, updated_at: :iso8601
      end
    end
  end
end

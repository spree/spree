# frozen_string_literal: true

module Spree
  module Api
    module V3
      class AssetSerializer < BaseSerializer
        # `type` is not exposed: Spree::Image/Spree::Video were collapsed into
        # Spree::Asset, so the STI column is a legacy vestige with no subclasses
        # — `media_type` is the discriminator (see MediaSerializer).
        typelize media_type: :string, viewable_type: :string,
                 viewable_id: :string, position: [:number, nullable: true],
                 alt: [:string, nullable: true]

        attribute :viewable_id do |asset|
          asset.viewable&.prefixed_id
        end

        # `"product"` / `"variant"`, not the polymorphic class name.
        attribute :viewable_type do |asset|
          Spree::Base.polymorphic_api_type(asset.viewable_type)
        end

        attributes :media_type, :position, :alt,
                   created_at: :iso8601, updated_at: :iso8601
      end
    end
  end
end

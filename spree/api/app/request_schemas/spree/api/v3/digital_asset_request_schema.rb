module Spree
  module Api
    module V3
      # What a downloadable file on a product carries, whichever panel writes
      # it. The operator's endpoint adds the provider fields on top.
      class DigitalAssetRequestSchema < Spree::Api::V3::RequestSchema
        # Names a blob rather than a column, so it is attached separately.
        attribute :signed_id, :string,
          permit: false,
          description: "A `signed_id` from `files.upload()` with `visibility: 'private'`. Required for an uploaded file, omitted for a provider-backed asset. On update it replaces the file for everyone who already bought it."
        # Resolved through the parent rather than assigned, so an asset can't
        # be pointed at a variant of another product or store.
        attribute :variant_id, :id,
          permit: false,
          description: "Defaults to the product's default variant when omitted."
        attribute :authorized_clicks, :integer,
          nullable: true,
          description: "Null means the store's download settings apply."
        attribute :authorized_days, :integer,
          nullable: true,
          description: "Null means the store's download settings apply."
      end
    end
  end
end

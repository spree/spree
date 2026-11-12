module Spree
  module DigitalAssets
    # Adds a downloadable file (or a provider-backed deliverable) to a product.
    #
    # The single gate for new assets: the operator's and the seller's nested
    # endpoints and the `digital_assets` list on a product write all run
    # through it, so a :validate handler sees every file a catalog gains.
    # A host that scans uploads registers on `digital_assets.create.validate`
    # for a quick check, or on `after_create` to queue a slower one; the bytes
    # are already in storage when either fires.
    #
    # Passing `seller:` applies the marketplace's rules for a seller's file —
    # whether sellers may upload at all, which content types, and whether an
    # approved listing goes back to review. The operator's own writes pass none.
    class Create < Spree::Workflow
      include Spree::DigitalAssets::Writing

      hooks :validate, :after_create

      # The unsaved record a :validate handler reads.
      attr_reader :digital_asset

      # @param product [Spree::Product]
      # @param attributes [Hash] `signed_id`, `variant_id`, the download limits
      #   and, for the operator, the provider fields
      # @param seller [Spree::Seller, nil] the seller this file is written for
      # @param submitted_by [Spree.admin_user_class, nil] who made the change,
      #   named on the review it may reopen
      # @return [Spree::ServiceModule::Result] value is the digital asset
      def perform(product:, attributes: {}, seller: nil, submitted_by: nil)
        super

        step :build_digital_asset
        step :resolve_upload
        step :enforce_seller_rules
        run_hooks :validate

        ApplicationRecord.transaction do
          step :attach_upload
          step :save_digital_asset
          step :reopen_review
          run_hooks :after_create
        end

        success(digital_asset)
      end

      private

      def build_digital_asset
        @digital_asset = Spree::DigitalAsset.new
        assign_attributes
      end
    end
  end
end

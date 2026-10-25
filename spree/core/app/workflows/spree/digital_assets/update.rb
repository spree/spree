module Spree
  module DigitalAssets
    # Changes a digital asset: its download limits, the variant it hangs off,
    # or the file itself. Replacing the file keeps every already-issued link
    # working, since links resolve through the asset rather than the blob.
    #
    # Handlers reading `digital_asset.changes` in :validate see the pending
    # edit; `blob` is the replacement file, when the payload carries one.
    class Update < Spree::Workflow
      include Spree::DigitalAssets::Writing

      hooks :validate, :after_update

      # @param digital_asset [Spree::DigitalAsset]
      # @param attributes [Hash] see Spree::DigitalAssets::Create
      # @param seller [Spree::Seller, nil] the seller this change is written for
      # @param submitted_by [Spree.admin_user_class, nil] who made the change
      # @return [Spree::ServiceModule::Result] value is the digital asset
      def perform(digital_asset:, attributes: {}, seller: nil, submitted_by: nil)
        super

        step :assign_attributes
        step :resolve_upload
        step :enforce_seller_rules
        run_hooks :validate

        ApplicationRecord.transaction do
          step :attach_upload
          step :save_digital_asset
          step :reopen_review
          run_hooks :after_update
        end

        success(digital_asset)
      end

      private

      def product
        digital_asset.product
      end
    end
  end
end

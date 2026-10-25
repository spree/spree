module Spree
  module DigitalAssets
    # The steps a file write shares between Create and Update: the upload the
    # payload names, the marketplace's rules for a seller's file, and sending
    # an approved listing back to review once what it delivers has changed.
    module Writing
      extend ActiveSupport::Concern

      # Why a product reopened review: recorded on the submission row so the
      # operator's queue says what changed.
      REVIEW_REASON = 'digital_asset_changed'.freeze

      included do
        # The uploaded file the payload names, resolved before it is attached.
        attr_reader :blob
      end

      private

      def assign_attributes
        attrs = attributes.to_h.with_indifferent_access
        @signed_id = attrs.delete(:signed_id)
        variant_id = attrs.delete(:variant_id)

        digital_asset.assign_attributes(attrs)
        # Through the product's own variants, so an asset reached through one
        # product can never point at another product's variant.
        digital_asset.variant = product.variants.find_by_param!(variant_id) if variant_id.present?
        digital_asset.variant ||= product.default_variant
      end

      def resolve_upload
        return if @signed_id.blank?

        @blob = ActiveStorage::Blob.find_signed(@signed_id)
        return refuse(:digital_assets_upload_not_found) if blob.nil?

        # Attaching never moves a blob between storage services, so a file
        # uploaded to the public bucket would stay publicly readable while
        # looking attached.
        unless blob.service_name.to_s == Spree.private_storage_service_name.to_s
          return refuse(:digital_assets_attachment_must_be_private)
        end

        # A provider-backed asset delivers through its provider, so a file on
        # it would show in the panel but never reach a buyer. An unregistered
        # provider is left to the model's validation rather than asked.
        return unless Spree.digital_asset_providers.include?(digital_asset.provider_class)

        refuse(:digital_assets_provider_takes_no_file) unless digital_asset.provider_class.requires_attachment?
      end

      # What the marketplace lets a seller attach. The operator's own writes
      # are not subject to these: the operator is who the rules protect.
      def enforce_seller_rules
        return if seller.nil?

        refuse(:digital_assets_sellers_disabled) unless store.preferred_seller_digital_assets_enabled
        return if blob.nil?

        # Identifying reads the file's own signature where it has one, so a
        # renamed executable cannot pass as a PDF; a format with no signature
        # (plain text) keeps the type the client declared.
        blob.identify_without_saving
        return if content_type_accepted?(blob.content_type)

        refuse(:digital_assets_content_type_not_accepted, content_type: blob.content_type)
      end

      # An entry names one type (`audio/mpeg`) or a whole family (`audio/*`).
      def content_type_accepted?(content_type)
        family = "#{content_type.to_s.split('/').first}/*"
        store.preferred_seller_digital_asset_content_types.any? { |accepted| accepted.casecmp?(content_type.to_s) || accepted == family }
      end

      def attach_upload
        digital_asset.attachment.attach(blob) if blob
      end

      def save_digital_asset
        failure(digital_asset) unless digital_asset.save
      end

      # A seller changing what an approved listing delivers reopens its review.
      # The operator's own change does not: they are the reviewer.
      def reopen_review
        return if seller.nil? || blob.nil? || !product.active?
        return unless store.preferred_review_seller_digital_asset_changes
        return if store.preferred_auto_approve_seller_products

        result = Spree.product_propose_workflow.call(product: product, submitted_by: submitted_by, reason: REVIEW_REASON)
        return if result.success?

        digital_asset.errors.add(:base, result.error.to_s)
        failure(digital_asset)
      end

      def store
        product.store
      end

      def refuse(key, **options)
        digital_asset.errors.add(:base, I18n.t("spree.#{key}", **options))
        failure(digital_asset)
      end
    end
  end
end

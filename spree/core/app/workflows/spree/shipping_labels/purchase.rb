module Spree
  module ShippingLabels
    # Buys a carrier label for a parcel through the owner's fulfillment
    # provider and records it as a Spree::ShippingLabel with the delivery it
    # mints (docs/plans/6.0-shipping-labels-and-deliveries.md).
    #
    # Idempotency lives here, not in the provider: an owner already holding an
    # active label is refused, so a provider is never asked twice and needs no
    # bookkeeping of its own. The file is fetched into private storage right
    # after purchase; a fetch that fails is retried in the background and the
    # provider's URL is kept until then.
    #
    # In the workflow tier for the carrier I/O and its hooks: a host app that
    # wants to veto a purchase (a cut-off window, a carrier allowlist) or act
    # on a bought label (print queue, cost ledger) hangs it here.
    class Purchase < Spree::Workflow
      hooks :validate, :after_purchase

      # The label that was bought, readable by hook handlers.
      attr_reader :shipping_label

      # @param owner [Spree::Fulfillment, Spree::Return] what the label ships
      # @return [Spree::ServiceModule::Result] the shipping label on success
      def perform(owner:)
        super

        run_hooks :validate

        step :ensure_purchasable
        step :claim_purchase, on_flow_failure: :release_claim

        # Carrier I/O — never inside a transaction.
        external_step :purchase

        ApplicationRecord.transaction do
          step :record_label
          step :record_delivery
        end

        step :store_file

        shipping_label.publish_event('shipping_label.purchased')
        run_hooks :after_purchase
        success(shipping_label.reload)
      end

      private

      def provider
        @provider ||= owner.provider
      end

      def ensure_purchasable
        failure(owner, Spree.t('shipping_labels.errors.provider_has_no_labels')) unless provider.class.generates_labels?
        failure(owner, Spree.t('shipping_labels.errors.already_purchased')) if owner.shipping_labels.active.exists?

        case owner
        when Spree::Fulfillment
          failure(owner, Spree.t('fulfillments.errors.cannot_purchase_label')) unless owner.unfulfilled?
          failure(owner, Spree.t('fulfillments.errors.order_draft')) if owner.order&.draft?
        when Spree::Return
          failure(owner, Spree.t('shipping_labels.errors.return_closed')) if owner.received? || owner.refunded? || owner.canceled?
        end
      end

      # The claim, not the check above, is what makes a double click buy one
      # label: it inserts the row the uniqueness index guards before the
      # carrier is called, so the loser of the race is refused by the
      # database rather than by a read that has already gone stale.
      def claim_purchase
        @shipping_label = owner.shipping_labels.create!(
          store: owner.store,
          integration: provider.integration_for(owner),
          source: 'purchased',
          status: 'purchased'
        )
      rescue ActiveRecord::RecordNotUnique
        failure(owner, Spree.t('shipping_labels.errors.already_purchased'))
      end

      # Undoes the claim when the carrier refuses, so a failed purchase does
      # not leave a row that refuses every later attempt.
      def release_claim
        @shipping_label&.destroy
        @shipping_label = nil
      end

      def purchase
        @purchase = provider.purchase_label(owner)

        return if @purchase.is_a?(Spree::LabelPurchase) && @purchase.valid?

        failure(owner, Spree.t('fulfillments.errors.label_purchase_failed'))
      end

      def record_label
        shipping_label.update!(
          external_id: @purchase.external_id,
          carrier: @purchase.carrier,
          service: @purchase.service,
          tracking_number: @purchase.tracking_number,
          cost: @purchase.cost || 0,
          currency: @purchase.currency,
          format: @purchase.format,
          metadata: (@purchase.metadata || {}).merge('file_url' => @purchase.file_url).compact
        )
      end

      # A label mints its own consignment. When the merchant already typed the
      # same number by hand, the delivery service binds that row rather than
      # letting a duplicate be refused.
      def record_delivery
        result = Spree.delivery_create_service.call(
          adopt: true,
          owner: owner,
          tracking_number: @purchase.tracking_number,
          carrier: @purchase.carrier,
          service: @purchase.service,
          tracking_url: @purchase.tracking_url,
          shipping_label: shipping_label
        )
        failure(shipping_label, result.error.to_s) if result.failure?
      end

      # Fetched in the background rather than in the request: the merchant has
      # already waited on one carrier call, and a slow label CDN would hold
      # the order lock the controller took for as long as it stalls. Until it
      # lands the download proxies the carrier's own copy, which is what
      # +file_pending?+ is for.
      def store_file
        return if @purchase.file_url.blank?

        Spree::ShippingLabels::StoreFileJob.perform_later(shipping_label.id)
      end
    end
  end
end

module Spree
  module FulfillmentProvider
    # Strategy handling create/track/cancel mechanics per fulfillment type.
    # Stored as a string class name on DeliveryMethod, constantized at call
    # time; registered via Spree.fulfillment_providers. Replaces the legacy
    # ShipmentHandler name-constantize mechanism.
    class Base
      include Spree::IntegrationBackedProvider

      class << self
        # Behavior predicates — the class hierarchy IS the vocabulary.
        # Subclasses override the one that describes their mechanics; admin
        # UIs and profile kinds compose against these, never string lists.
        def digital?
          false
        end

        def pickup?
          false
        end

        def pickup_point?
          false
        end

        # Whether this provider produces shipping labels (and so supports the
        # explicit buy-label step before fulfilling). Carrier gems override.
        def generates_labels?
          false
        end

      end

      # @return [Boolean] whether the fulfillment may transition to fulfilled
      def can_fulfill?(_fulfillment)
        true
      end

      # Whether fulfillments handled by this provider fulfill themselves on
      # order completion (digital delivery).
      def auto_fulfill?
        false
      end

      # Whether this provider dispatches to a customer shipping address.
      # Address-free providers (digital, the pickup kinds) override to false;
      # it also drives delivery-zone checks, which describe the customer
      # destination.
      def requires_address?
        true
      end

      # Whether packages originating from this stock location may use the
      # method — answered by the method's origin group (no group or no
      # members means every location). Pickup overrides with its own policy
      # semantics (pickup-enabled counters, ship-to-store transfers).
      def serves_location?(delivery_method, stock_location)
        group = delivery_method.delivery_origin_group
        return true if group.nil?

        group.covers_location?(stock_location)
      end

      # Buys a carrier label for the owner — a +Spree::Fulfillment+ for an
      # outbound parcel, a +Spree::Return+ for the inbound one. Core turns the
      # answer into a +Spree::ShippingLabel+ and its +Spree::Delivery+, and
      # never asks twice for an owner that already holds an active label, so
      # a provider needs no idempotency bookkeeping of its own. Only
      # providers answering +generates_labels?+ are asked.
      #
      # @param _owner [Spree::Fulfillment, Spree::Return]
      # @return [Spree::LabelPurchase, nil] nil when no label could be bought
      def purchase_label(_owner)
        nil
      end

      # Asks the carrier to refund a purchased label.
      #
      # @param _shipping_label [Spree::ShippingLabel]
      # @return [String, false] +'refunded'+ when the carrier settled it,
      #   +'refund_requested'+ when it will answer later, false when refused
      def refund_label(_shipping_label)
        false
      end

      # Performs the provider-side dispatch when a fulfillment fulfills — a
      # 3PL pick, a pickup counter, digital links. Label-generating providers
      # implement +purchase_label+ instead.
      #
      # @return [Hash] optionally { tracking_number:, tracking_url: }
      def create_fulfillment(_fulfillment)
        raise NotImplementedError, "Please implement 'create_fulfillment' in your fulfillment provider: #{self.class.name}"
      end

      # Cancels the provider-side dispatch.
      def cancel_fulfillment(_fulfillment)
        raise NotImplementedError, "Please implement 'cancel_fulfillment' in your fulfillment provider: #{self.class.name}"
      end

      # The provider's own tracker page for a consignment.
      #
      # @param _delivery [Spree::Delivery]
      # @return [String, nil]
      def tracking_url(_delivery)
        nil
      end

      # Documents the provider produced beside the label — customs forms,
      # commercial invoices. The label itself is a +Spree::ShippingLabel+ and
      # is never reported here.
      #
      # @param _owner [Spree::Fulfillment, Spree::Return]
      # @return [Array<Spree::ShippingDocument>]
      def documents(_owner)
        []
      end

      # The connected, active integration carrying this provider's
      # credentials, resolved from the owner's store.
      #
      # @param owner [Spree::Fulfillment, Spree::Return]
      # @return [Spree::Integration, nil]
      def integration_for(owner)
        return if self.class.integration_class.blank?

        owner.store&.integrations&.active&.find_by(type: self.class.integration_class)
      end
    end
  end
end

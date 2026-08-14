module Spree
  # When a customer's card is charged, as opposed to only authorized.
  #
  # A store sets the default and a payment method may override it, mirroring
  # +Spree::Channel::Gating+: the method preference is nullable, so an unset
  # value inherits the store's choice rather than meaning "checkout".
  module CaptureMethod
    extend ActiveSupport::Concern

    # - +checkout+     charge as soon as the order is placed
    # - +on_dispatch+  authorize at checkout, charge when goods are dispatched
    # - +manual+       authorize at checkout, leave charging to staff
    CAPTURE_METHODS = %w[checkout on_dispatch manual].freeze

    # The value a store falls back to when nothing has been chosen.
    DEFAULT_CAPTURE_METHOD = 'checkout'.freeze

    # @return [Boolean] true when the money is taken as the order is placed.
    def capture_at_checkout?
      resolved_capture_method == 'checkout'
    end

    # @return [Boolean] true when dispatching goods is what triggers the charge.
    def capture_on_dispatch?
      resolved_capture_method == 'on_dispatch'
    end

    # @return [Boolean] true when only staff may take the money.
    def capture_manually?
      resolved_capture_method == 'manual'
    end
  end
end

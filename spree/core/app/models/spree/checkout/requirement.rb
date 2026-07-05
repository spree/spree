module Spree
  module Checkout
    # Value object representing a single additional requirement registered via {Registry}.
    #
    # Unlike {Step}, a Requirement attaches extra validation to an *existing* checkout step
    # rather than introducing a new step.
    #
    # @example Require a PO number for B2B orders at the payment step
    #   Spree::Checkout::Registry.add_requirement(
    #     step: :payment,
    #     field: :po_number,
    #     message: 'PO number is required for business accounts',
    #     satisfied: ->(order) { order.po_number.present? },
    #     applicable: ->(order) { order.account&.business? }
    #   )
    class Requirement
      # @return [String] checkout step this requirement belongs to
      attr_reader :step

      # @return [String] field identifier (e.g. +"po_number"+, +"tax_id"+)
      attr_reader :field

      # @return [String] human-readable message shown when the requirement is not met
      attr_reader :message

      # @param step [String, Symbol] checkout step this requirement belongs to
      # @param field [String, Symbol] field identifier
      # @param message [String] human-readable validation message
      # @param satisfied [Proc] lambda accepting an order, returns true when met
      # @param applicable [Proc] lambda accepting an order, returns true when this requirement applies
      #   (defaults to always applicable)
      def initialize(step:, field:, message:, satisfied:, applicable: ->(_) { true })
        @step = step.to_s
        @field = field.to_s
        @message = message
        @satisfied_proc = satisfied
        @applicable_proc = applicable
      end

      # @param order [Spree::Order]
      # @return [Boolean] whether the requirement has been met
      def satisfied?(order) = @satisfied_proc.call(order)

      # @param order [Spree::Order]
      # @return [Boolean] whether this requirement applies to the given order
      def applicable?(order) = @applicable_proc.call(order)
    end
  end
end

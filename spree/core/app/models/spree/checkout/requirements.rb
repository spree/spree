module Spree
  module Checkout
    # Aggregates all checkout requirements for an order.
    #
    # Combines built-in checks from {DefaultRequirements} with custom steps and
    # requirements registered in {Registry}. The resulting array of hashes is
    # exposed on the Cart API as the +requirements+ attribute.
    #
    # Each requirement hash has the shape:
    #   { step: String, field: String, message: String }
    #
    # @example
    #   reqs = Spree::Checkout::Requirements.new(order)
    #   reqs.call  # => [{ step: "address", field: "email", message: "Email address is required" }]
    #   reqs.met?  # => false
    class Requirements
      # @param order [Spree::Order]
      def initialize(order)
        @order = order
      end

      # @return [Array<Hash{Symbol => String}>] all unmet requirements
      def call
        default + from_registered_steps + from_additional_requirements
      end

      # @return [Boolean] true when all requirements are satisfied
      def met?
        call.empty?
      end

      private

      # @return [Array<Hash>] built-in checkout requirements
      def default
        DefaultRequirements.new(@order).call
      end

      # @return [Array<Hash>] requirements from unsatisfied registered steps
      def from_registered_steps
        Registry.ordered_steps
          .select { |s| s.applicable?(@order) }
          .reject { |s| s.satisfied?(@order) }
          .flat_map { |s| s.requirements(@order) }
      end

      # @return [Array<Hash>] requirements from unsatisfied registered requirements
      def from_additional_requirements
        Registry.requirements
          .select { |r| r.applicable?(@order) }
          .reject { |r| r.satisfied?(@order) }
          .map { |r| { step: r.step, field: r.field, message: r.message } }
      end
    end
  end
end

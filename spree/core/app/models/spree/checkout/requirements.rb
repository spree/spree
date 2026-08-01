module Spree
  module Checkout
    # Aggregates all checkout requirements for a cart.
    #
    # Combines built-in checks from {DefaultRequirements} with custom steps and
    # requirements registered in {Registry}. The resulting array of hashes is
    # exposed on the Cart API as the +requirements+ attribute.
    #
    # Each requirement hash has the shape:
    #   { step: String, field: String, message: String }
    #
    # @example
    #   reqs = Spree::Checkout::Requirements.new(cart)
    #   reqs.call  # => [{ step: "address", field: "email", message: "Email address is required" }]
    #   reqs.met?  # => false
    class Requirements
      # @param cart [Spree::Cart]
      def initialize(cart)
        @cart = cart
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
        DefaultRequirements.new(@cart).call
      end

      # @return [Array<Hash>] requirements from unsatisfied registered steps
      def from_registered_steps
        Registry.ordered_steps
          .select { |s| s.applicable?(@cart) }
          .reject { |s| s.satisfied?(@cart) }
          .flat_map { |s| s.requirements(@cart) }
      end

      # @return [Array<Hash>] requirements from unsatisfied registered requirements
      def from_additional_requirements
        Registry.requirements
          .select { |r| r.applicable?(@cart) }
          .reject { |r| r.satisfied?(@cart) }
          .map { |r| { step: r.step, field: r.field, message: r.message } }
      end
    end
  end
end

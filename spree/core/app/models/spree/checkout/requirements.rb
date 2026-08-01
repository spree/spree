module Spree
  module Checkout
    # Aggregates all checkout requirements for a cart — the single source of
    # truth for "what does this cart still need". Combines built-in checks
    # from {DefaultRequirements} with custom steps and requirements
    # registered in {Registry}. The resulting array of hashes is exposed on
    # the Cart API as the +requirements+ attribute; with +completion: true+
    # it includes the heavier completion-only checks (stock, discontinued,
    # guest policy) and is exactly what Spree::Carts::Complete gates
    # completion on.
    #
    # Each requirement hash has the shape:
    #   { step: String, field: String, code: String, message: String }
    #
    # @example
    #   reqs = Spree::Checkout::Requirements.new(cart)
    #   reqs.call  # => [{ step: "address", field: "email", code: "email_required", message: "Email address is required" }]
    #   reqs.met?  # => false
    class Requirements
      # @param cart [Spree::Cart]
      def initialize(cart)
        @cart = cart
      end

      # @param completion [Boolean] include the completion-only checks
      # @return [Array<Hash{Symbol => String}>] all unmet requirements
      def call(completion: false)
        requirements = default(completion: completion) + from_registered_steps + from_additional_requirements
        requirements.map { |requirement| { code: "#{requirement[:field]}_required" }.merge(requirement) }
      end

      # @return [Boolean] true when all requirements are satisfied
      def met?
        call.empty?
      end

      private

      # @return [Array<Hash>] built-in checkout requirements
      def default(completion:)
        DefaultRequirements.new(@cart).call(completion: completion)
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

module Spree
  module TestingSupport
    # Swaps the registered company activation policy for one example, always
    # restoring the previous registration — the dependency registry is shared
    # process-wide, so a policy left behind would decide activation for
    # whatever runs next.
    module CompanyActivationPolicy
      # A policy deactivating the given companies AND everything below them
      # (the contract a conforming policy implements — a suspended parent
      # covers its divisions), everything else staying active.
      #
      #   with_company_activation_policy(inactive: [company]) do
      #     ...
      #   end
      #
      # @param inactive [Array<Spree::Company>] companies whose subtrees the
      #   policy answers inactive for
      def with_company_activation_policy(inactive: [])
        original = Spree::Dependencies.company_activation_policy_class
        Spree::Dependencies.company_activation_policy_class = deactivating_policy_class(inactive)
        yield
      ensure
        Spree::Dependencies.company_activation_policy_class = original
      end

      private

      # Subtree membership is asked per call, not snapshotted at swap time,
      # so a node created inside the block under an inactive parent answers
      # inactive too.
      def deactivating_policy_class(inactive_companies)
        Class.new(Spree::Companies::ActivationPolicy) do
          define_method(:active?) do |company|
            !Spree::Company.subtree_of(inactive_companies).where(id: company.id).exists?
          end
        end
      end
    end
  end
end

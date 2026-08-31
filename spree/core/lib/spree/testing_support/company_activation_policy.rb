module Spree
  module TestingSupport
    # Swaps the registered company activation policy for one example, always
    # restoring the previous registration — the dependency registry is shared
    # process-wide, so a policy left behind would decide activation for
    # whatever runs next.
    module CompanyActivationPolicy
      # A policy deactivating exactly the given companies, everything else
      # staying active — the smallest deviation from the OSS default.
      #
      #   with_company_activation_policy(inactive: [company]) do
      #     ...
      #   end
      #
      # @param policy_class [Class, nil] a full replacement policy
      # @param inactive [Array<Spree::Company>] companies the policy answers
      #   inactive for (ignored when policy_class is given)
      def with_company_activation_policy(policy_class = nil, inactive: [])
        policy_class ||= deactivating_policy_class(inactive.map(&:id))
        original = Spree::Dependencies.company_activation_policy_class
        Spree::Dependencies.company_activation_policy_class = policy_class
        yield
      ensure
        Spree::Dependencies.company_activation_policy_class = original
      end

      private

      def deactivating_policy_class(inactive_ids)
        Class.new(Spree::Companies::ActivationPolicy) do
          define_method(:active?) { |company| !inactive_ids.include?(company.id) }
        end
      end
    end
  end
end

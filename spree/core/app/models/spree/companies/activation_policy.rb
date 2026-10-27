module Spree
  module Companies
    # Whether a company may act commercially — see catalogs, be priced by
    # its agreements, be bought for. The single answer every company-resolving
    # read consults: catalog resolution, sole-standing resolution, cart
    # +company_id+ writes and the +approval_required+ storefront posture
    # (docs/plans/6.0-b2b-company-self-registration.md).
    #
    # The OSS default activates every company, so self-registration is
    # instant and the +approval_required+ posture reads "company members
    # only". An approval flow replaces this class via
    # `Spree::Dependencies.company_activation_policy_class`; subtree
    # semantics are the replacement's job, which is why {#active?} takes the
    # node — and a policy suspending a parent MUST answer inactive for every
    # node below it too, or a member's standing over a still-"active"
    # division keeps showing prices the suspended tree may not see.
    #
    # Self-service standing (company pages, members, invitations, the
    # address book) never consults this policy — members of an inactive
    # company keep their workspace while they wait.
    class ActivationPolicy
      # Whether the company may act commercially.
      #
      # @param _company [Spree::Company]
      # @return [Boolean]
      def active?(_company)
        true
      end

      # The +pricing_access+ reason code for a viewer an +approval_required+
      # channel withholds prices from, or nil when prices are visible.
      #
      # @param user [Object, nil] the authenticated customer, nil for guests
      # @param store [Spree::Store, nil]
      # @return [String, nil] +login_required+ | +company_required+ | a
      #   policy-supplied code | nil
      def pricing_access_code(user:, store:)
        return 'login_required' if user.blank?
        # Standing is a customer's fact about a business — anything else
        # (an admin principal, a value object) has none, mirroring
        # Company.sole_standing_for's type check.
        return 'company_required' unless user.is_a?(Spree.customer_class)

        # Standing is store-scoped, so without a store there is nothing to
        # hold standing in.
        return 'company_required' if store.nil?

        # The membership nodes are enough: a conforming policy suspending a
        # parent answers inactive for everything below it, so expanding to
        # the standing subtree could not change the answer — it would only
        # load it. Lazily, so a policy that reads persisted state is asked
        # about as few nodes as the answer needs.
        memberships = user.companies.where(store_id: store.id)
        return nil if memberships.lazy.any? { |company| active?(company) }

        'company_required'
      end
    end
  end
end

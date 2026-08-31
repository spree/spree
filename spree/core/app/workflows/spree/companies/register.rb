module Spree
  module Companies
    # Founds a company from the storefront — the B2B front door
    # (docs/plans/6.0-b2b-company-self-registration.md): an authenticated
    # customer creates a root node plus their own membership in one call.
    # Companies are born active; whether they may act commercially is the
    # activation policy's answer, so a registered approval flow makes this
    # instant registration an application instead without touching it.
    #
    # The `validate` hook is the screening point (domain rules, fraud
    # checks); it fires only here — joining an existing company through
    # {Spree::CompanyInvitations::Accept} is not founding one. Free-form
    # registration answers land in `metadata['registration']`. Core
    # publishes `company.registered` and sends no mail.
    class Register < Spree::Workflow
      hooks :validate, :after_register

      # The company being founded — built (unsaved) while :validate runs.
      attr_reader :company

      # The founder's membership on it.
      attr_reader :membership

      # @param store [Spree::Store] the store the business registers with
      # @param customer [Object] the authenticated customer founding it
      # @param name [String] the company name
      # @param registration [Hash, nil] free-form registration answers,
      #   stored under `metadata['registration']`
      # @param metadata [Hash, nil]
      def perform(store:, customer:, name:, registration: nil, metadata: nil)
        super

        step :ensure_no_existing_root
        step :build_company

        # Veto point — registration screening. The company is built but not
        # yet persisted.
        run_hooks :validate

        ApplicationRecord.transaction do
          # The early guard is check-then-insert; serializing concurrent
          # registrations on the founder's row and re-checking under the lock
          # keeps a double-clicked form from founding two businesses.
          step :lock_founder
          step :confirm_sole_founding
          step :create_company
          step :create_membership
        end

        step :publish_registered
        run_hooks :after_register
        success(company)
      end

      private

      # At most one root company per customer per store: a duplicate
      # submission must not found a second business, and a buyer who really
      # operates two asks staff. Any root membership counts — founded or
      # joined at the top of someone's tree, the customer already has a
      # business here (recorded decision, 2026-08-31); only division-level
      # memberships leave registration open.
      def ensure_no_existing_root
        return unless holds_root_membership?

        errors.add(:base, :already_registered, message: Spree.t('company_registration.already_registered'))
        reject!
      end

      def holds_root_membership?
        store.companies.roots.
          joins(:memberships).
          where(Spree::CompanyMembership.table_name => { customer_id: customer.id }).
          exists?
      end

      # Serializes concurrent registrations by the same customer: the second
      # request blocks here until the first commits, and the re-check then
      # sees its root.
      def lock_founder
        customer.lock!
      end

      def confirm_sole_founding
        return unless holds_root_membership?

        errors.add(:base, :already_registered, message: Spree.t('company_registration.already_registered'))
        reject!
      end

      def build_company
        @company = store.companies.new(
          name: name,
          kind: 'company',
          metadata: company_metadata
        )
      end

      def company_metadata
        combined = (metadata || {}).deep_stringify_keys
        combined['registration'] = registration.deep_stringify_keys if registration.present?
        combined
      end

      def create_company
        failure(company) unless company.save
      end

      def create_membership
        @membership = company.memberships.new(customer: customer)
        failure(membership) unless membership.save
      end

      def publish_registered
        company.publish_event('company.registered')
      end
    end
  end
end

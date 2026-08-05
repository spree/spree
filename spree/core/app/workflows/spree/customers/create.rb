module Spree
  module Customers
    # Creates a customer account — the single storefront registration flow
    # (docs/plans/6.0-service-workflows.md decision 13).
    #
    # Two callers today: store self-registration and the checkout "create an
    # account" box, which passes `order:` — the customer is built from the
    # order without a password (the account is claimed via password reset,
    # like an admin-created one), the order's addresses become the account's
    # defaults and the order is linked to the new account.
    #
    # The `validate` hook is the veto seam for registration policy —
    # bot/disposable-email screening, fraud checks, B2B approval. Handlers
    # read the built (unsaved) `customer` plus `order`/`created_by`; staff
    # bypass is a handler decision via `created_by`, the same pattern as
    # return eligibility. Core sends no welcome email — signup email is
    # host-app code on the `user.created` event or the `after_create` hook.
    class Create < Spree::Workflow
      hooks :validate, :after_create

      # The customer record — built (unsaved) while :validate runs.
      attr_reader :customer

      # @param store [Spree::Store] the store the registration happens on;
      #   exposed to hook handlers and scopes the newsletter-subscriber link
      # @param email [String, nil] defaults to the order email with `order:`
      # @param password [String, nil]
      # @param password_confirmation [String, nil]
      # @param first_name [String, nil] defaults from the order addresses
      #   with `order:`, as do last_name and phone
      # @param last_name [String, nil]
      # @param phone [String, nil]
      # @param accepts_email_marketing [Boolean, nil] defaults from the
      #   order's marketing opt-in with `order:`
      # @param metadata [Hash, nil]
      # @param order [Spree::Order, nil] a placed order adopting the new
      #   account; when its email already belongs to a customer, the order is
      #   linked to that account and no new customer is created
      # @param password_required [Boolean, nil] whether a missing password
      #   fails the registration (the account is created password-less
      #   otherwise and claimed via password reset). Defaults to true except
      #   with `order:` — guest checkout collects no password, while
      #   self-registration must, because the caller issues a JWT on success
      # @param created_by [Object, nil] the staff actor; nil for storefront
      #   self-registration
      def perform(store:, email: nil, password: nil, password_confirmation: nil,
                  first_name: nil, last_name: nil, phone: nil,
                  accepts_email_marketing: nil, metadata: nil,
                  order: nil, password_required: nil, created_by: nil)
        super

        step :adopt_existing_customer
        step :build_customer
        step :ensure_password

        # Veto point — registration policy. The customer is built but not
        # yet persisted.
        run_hooks :validate

        ApplicationRecord.transaction do
          step :create_customer
          step :link_order
        end

        step :link_newsletter_subscriber
        run_hooks :after_create
        success(order ? customer.reload : customer)
      end

      private

      # Checkout only: an account with the order's email already exists, so
      # the order joins it instead of registering a duplicate. Registration
      # policy hooks don't run — nothing is being registered.
      def adopt_existing_customer
        return unless order

        existing_customer = Spree.customer_class.find_by(email: order.email)
        return unless existing_customer

        order.associate_customer!(existing_customer, false)
        halt!(existing_customer)
      end

      def build_customer
        @customer = Spree.customer_class.new(customer_attributes)
      end

      def customer_attributes
        order_address = order && (order.bill_address || order.ship_address)

        {
          email: email || order&.email,
          password: password,
          password_confirmation: password_confirmation,
          first_name: first_name || order_address&.firstname,
          last_name: last_name || order_address&.lastname,
          phone: phone || order_address&.phone,
          accepts_email_marketing: accepts_email_marketing.nil? ? order&.accept_marketing? : accepts_email_marketing,
          metadata: metadata
        }.compact
      end

      # The model itself allows a blank password — a password-less account
      # cannot log in (Customer#valid_password? guards the blank digest) and
      # is claimed via password reset; whether registration accepts that
      # state is the password_required policy. No password is generated:
      # blank is the one unclaimed-account state everywhere, and a generated
      # value could fail a host's swapped-in Spree.password_validator.
      def ensure_password
        return if customer.password.present? || !password_required?

        customer.errors.add(:password, :blank)
        failure(customer)
      end

      def password_required?
        password_required.nil? ? order.nil? : password_required
      end

      def create_customer
        failure(customer) unless customer.save
      end

      def link_order
        return unless order

        adopt_addresses
        order.associate_customer!(customer, false)
      end

      # The order's addresses become the new account's defaults — but only
      # unowned ones: an address already in another customer's address book
      # must not be re-homed onto the new account.
      # update_columns because the order is already placed and the address
      # already validated — re-running validations here could reject a
      # linkage the checkout accepted.
      def adopt_addresses
        addresses = { bill_address_id: order.bill_address, ship_address_id: order.ship_address }.
          select { |_, address| address.present? && address.customer_id.nil? }
        return if addresses.empty?

        addresses.values.uniq.each do |address|
          address.update_columns(customer_id: customer.id, updated_at: Time.current)
        end

        customer.update_columns(addresses.transform_values(&:id).merge(updated_at: Time.current))
      end

      # Someone who subscribed to the newsletter before registering gets their
      # subscription linked to the new account, with verified opt-in carried
      # over. Best-effort by design — see Spree::Newsletter::LinkUser.
      def link_newsletter_subscriber
        subscriber = Spree::NewsletterSubscriber.find_by(email: customer.email, store: store)
        Spree::Newsletter::LinkUser.new(subscriber: subscriber, user: customer).call
      end
    end
  end
end

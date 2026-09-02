module Spree
  module Customers
    # Erases a customer's personal data while leaving the business record
    # intact — GDPR Art. 17 against the accounting-retention obligations that
    # outlive it.
    #
    # The distinction this flow rests on: an order is not personal data, it is
    # a financial record with personal data attached. So totals, tax lines,
    # line items, payments and refunds are never touched, and everything that
    # identifies a person is replaced. Deletion is not on offer — destroying
    # completed orders would trade one legal obligation for another, which is
    # why `Spree::Customer` refuses to be destroyed once it has bought
    # something.
    #
    # Jurisdiction survives on purpose. City, state, country and a truncated
    # postcode stay readable on order addresses because a tax audit has to
    # establish where a sale was taxed; a street line and a name do not serve
    # that and go.
    #
    # This is the only sanctioned erasure path. Anything that adds a table
    # carrying customer-identifiable data extends this flow in the same
    # change — there is a schema guard spec that fails when it does not.
    class Anonymize < Spree::Workflow
      hooks :validate, :after_anonymize

      # What replaces a name. Recognisable as a tombstone rather than looking
      # like a real person called Anonymized.
      REDACTED_NAME = 'Redacted'.freeze
      REDACTED_VALUE = 'Redacted'.freeze

      # A reserved TLD (RFC 2606), so an anonymized address can never be
      # delivered to and can never collide with a real one.
      REDACTED_DOMAIN = 'invalid'.freeze

      # @param customer [Spree::Customer] the data subject
      # @param store [Spree::Store, nil] the store the request arrived at,
      #   recorded on the event. Customers are global, so anonymization is
      #   too — a person cannot be erased from one store and remembered by
      #   its sibling.
      # @param requested_by [Object, nil] the staff actor; nil for
      #   self-service erasure
      # @return [Spree::ServiceModule::Result] the anonymized customer
      def perform(customer:, store: nil, requested_by: nil)
        super

        step :capture_original_email
        step :ensure_not_already_anonymized

        # Veto point — a host app that must keep a customer identifiable for
        # an open dispute, a fraud investigation or a legal hold rejects here.
        run_hooks :validate

        ApplicationRecord.transaction do
          step :anonymize_account
          step :anonymize_address_book
          step :anonymize_order_addresses
          step :anonymize_purchases
          step :anonymize_payment_sources
          step :anonymize_identities
          step :anonymize_sessions
          step :anonymize_consent_records
          step :anonymize_data_requests
          step :remove_newsletter_subscriptions
          step :stamp_anonymized
        end

        customer.publish_event('customer.anonymized', store_id: store&.prefixed_id)

        run_hooks :after_anonymize
        success(customer.reload)
      end

      private

      # Read before anything rewrites it — guest rows are found by address.
      def capture_original_email
        @original_email = customer.email
      end

      def ensure_not_already_anonymized
        return if customer.anonymized_at.nil?

        failure(customer, Spree.t('customer_errors.already_anonymized'))
      end

      # The account itself. `update_columns` throughout this flow: validations
      # and callbacks have nothing to add to a redaction, and the email
      # uniqueness check would be a wasted query against a UUID.
      def anonymize_account
        customer.update_columns(
          email: anonymous_email,
          first_name: REDACTED_NAME,
          last_name: REDACTED_NAME,
          phone: nil,
          accepts_email_marketing: false,
          email_marketing_consent_updated_at: Time.current,
          email_marketing_consent_source: 'anonymization',
          selected_locale: nil,
          metadata: {},
          internal_note: nil,
          updated_at: Time.current
        )

        customer.avatar.purge_later if customer.avatar.attached?
      end

      # The customer's own address book — soft-deleted as well as scrubbed,
      # since nothing needs to render it again.
      #
      # Reads the table rather than `customer.addresses`, which is scoped to
      # `deleted_at: nil`: an address the person removed years ago is still
      # their street address sitting in the database, and erasure has to reach
      # it.
      def anonymize_address_book
        Spree::Address.where(owner_type: customer.class.base_class.to_s, owner_id: customer.id).
          find_each do |address|
            redact_address(address, deleted: true)
          end
      end

      # Address snapshots on orders and carts. These are not the customer's
      # address book: they are what was on the purchase at the time, and the
      # order keeps them.
      #
      # Carts are their own table since the Cart/Order split, so an abandoned
      # checkout holds its own copy of wherever the person was having it sent.
      def anonymize_order_addresses
        address_ids = [
          Spree::Order.where(customer_id: customer.id).pluck(:bill_address_id, :ship_address_id),
          Spree::Cart.where(customer_id: customer.id).pluck(:bill_address_id, :ship_address_id)
        ].flatten.compact.uniq
        return if address_ids.empty?

        Spree::Address.where(id: address_ids).find_each do |address|
          redact_address(address, deleted: false)
        end
      end

      # Orders, carts and order groups. The money stays; the person goes.
      #
      # An abandoned cart is not a financial record and could simply be
      # deleted, but scrubbing it keeps one rule for every purchase-shaped row
      # and leaves nothing for a later feature to resurrect.
      def anonymize_purchases
        scrubbed = {
          email: customer.email,
          customer_note: nil,
          last_ip_address: nil,
          metadata: {},
          updated_at: Time.current
        }

        # Orders carry a staff-written note that carts have no column for, so
        # each is scrubbed to the columns it actually has.
        Spree::Order.where(customer_id: customer.id).update_all(scrubbed.merge(internal_note: nil))
        Spree::Cart.where(customer_id: customer.id).update_all(scrubbed)

        Spree::OrderGroup.where(customer_id: customer.id).
          update_all(email: customer.email, updated_at: Time.current)
      end

      # Cards keep their last four digits and expiry — a refund to a card on a
      # retained order has to be traceable — but lose the cardholder name, and
      # the profiles at the gateway are released so the processor stops
      # holding the person too.
      def anonymize_payment_sources
        customer.credit_cards.find_each do |card|
          card.update_columns(name: REDACTED_NAME, deleted_at: Time.current, updated_at: Time.current)
        end

        customer.gateway_customers.destroy_all
      end

      def anonymize_identities
        customer.identities.destroy_all
      end

      # Refresh tokens carry an IP and a user agent, and an anonymized account
      # should not stay signed in anywhere.
      def anonymize_sessions
        Spree::RefreshToken.where(user_type: customer.class.base_class.to_s, user_id: customer.id).delete_all
      end

      # The consent rows keep their purpose, source and timestamp — the proof
      # that consent was given survives the person — but lose the contact
      # details and device fingerprints attached to them.
      #
      # Matched by email as well as by owner: a guest checkout records consent
      # against the ORDER, not the account, so a person who bought as a guest
      # before registering has rows this customer does not own.
      def anonymize_consent_records
        Spree::ConsentRecord.
          where(owner_type: customer.class.base_class.to_s, owner_id: customer.id).
          or(Spree::ConsentRecord.where(email: erased_emails)).
          update_all(email: nil, ip_address: nil, user_agent: nil, updated_at: Time.current)
      end

      # The requests themselves carry the address they were made from. The
      # record of the request survives — a controller has to be able to show
      # it answered one — but the address on it is the very thing being
      # erased, so it becomes the anonymized one.
      def anonymize_data_requests
        Spree::DataRequest.where(customer_id: customer.id).
          update_all(email: customer.email, updated_at: Time.current)
      end

      # Matched by email as well as by customer: guest checkout subscribes with
      # `customer: nil`, so the person's address sits in a row that never
      # pointed at an account.
      def remove_newsletter_subscriptions
        Spree::NewsletterSubscriber.
          where(customer_id: customer.id).
          or(Spree::NewsletterSubscriber.where(email: erased_emails)).
          destroy_all
      end

      def stamp_anonymized
        customer.update_columns(anonymized_at: Time.current, updated_at: Time.current)
      end

      # @param address [Spree::Address]
      # @param deleted [Boolean] whether to soft-delete it as well
      def redact_address(address, deleted:)
        attributes = {
          firstname: REDACTED_NAME,
          lastname: REDACTED_NAME,
          address1: REDACTED_VALUE,
          address2: nil,
          phone: nil,
          alternative_phone: nil,
          company: nil,
          label: nil,
          latitude: nil,
          longitude: nil,
          zipcode: truncated_zipcode(address.zipcode),
          metadata: {},
          updated_at: Time.current
        }
        attributes[:deleted_at] = Time.current if deleted && address.deleted_at.nil?

        address.update_columns(attributes)
      end

      # Keeps enough for a tax jurisdiction, drops enough that it no longer
      # points at a household. The leading characters are the coarse part of
      # every postcode system we serve.
      #
      # @param zipcode [String, nil]
      # @return [String, nil]
      def truncated_zipcode(zipcode)
        return nil if zipcode.blank?

        zipcode.to_s.strip.first(2)
      end

      def anonymous_email
        @anonymous_email ||= "anonymized-#{SecureRandom.uuid}@#{REDACTED_DOMAIN}"
      end

      # The addresses this person was known by. Captured before the account is
      # rewritten, because rows that never pointed at the account can only be
      # found by the address they carry.
      #
      # @return [Array<String>]
      def erased_emails
        @erased_emails ||= [@original_email, customer.email].compact_blank.uniq
      end
    end
  end
end

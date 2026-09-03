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
      include Spree::PersonalDataMatching

      hooks :validate, :after_anonymize

      # What replaces a name. Recognisable as a tombstone rather than looking
      # like a real person called Anonymized.
      REDACTED_NAME = 'Redacted'.freeze

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
          # Both read the purchases by email, so they run before the step that
          # rewrites it.
          step :anonymize_payment_sources
          step :anonymize_purchases
          step :forget_gateway_profiles
          step :anonymize_identities
          step :anonymize_sessions
          step :anonymize_merchant_annotations
          step :remove_tax_identifiers
          step :anonymize_consent_records
          step :anonymize_data_requests
          step :record_consent_withdrawal
          step :remove_newsletter_subscriptions
          step :stamp_anonymized
        end

        customer.publish_event(
          'customer.anonymized',
          store_id: store&.prefixed_id,
          requested_by_id: requested_by&.prefixed_id
        )

        run_hooks :after_anonymize
        success(customer.reload)
      end

      private

      # Read before anything rewrites it — guest rows are found by address.
      def capture_original_email
        @original_email = customer.email
        @accepted_marketing = customer.accepts_email_marketing?
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
          email_marketing_consent_source: Spree::ConsentRecord::ANONYMIZATION,
          selected_locale: nil,
          metadata: {},
          internal_note: nil,
          # The credential goes with the identity. Left in place, whoever knew
          # the old password could sign back in and write the name and phone
          # straight back — and a second erasure would then be refused as
          # already done.
          password_digest: nil,
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
      # checkout holds its own copy of wherever the person was having it sent,
      # and a checkout split across sellers keeps one on the group beside the
      # copies on each seller's order.
      def anonymize_order_addresses
        address_ids = [
          owned_purchases(Spree::Order).pluck(:bill_address_id, :ship_address_id),
          owned_purchases(Spree::Cart).pluck(:bill_address_id, :ship_address_id),
          owned_purchases(Spree::OrderGroup).pluck(:bill_address_id, :ship_address_id)
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
        owned_purchases(Spree::Order).update_all(scrubbed.merge(internal_note: nil))
        owned_purchases(Spree::Cart).update_all(scrubbed)

        owned_purchases(Spree::OrderGroup).
          update_all(email: customer.email, updated_at: Time.current)
      end

      # Everything this person bought, however they were signed in at the time.
      #
      # Matched by email as well as by customer, because a guest checkout
      # leaves `customer_id` null: someone who ordered as a guest and
      # registered afterwards has purchases carrying their address and IP that
      # the account does not own.
      #
      # @param model [Class]
      # @return [ActiveRecord::Relation]
      def owned_purchases(model)
        rows_about_person(model, email: @original_email, customer_id: customer.id)
      end

      # Cards keep their last four digits and expiry — a refund against a
      # retained order has to be traceable — and lose the cardholder name.
      #
      # Deliberately NOT soft-deleted: `Spree::Payment#source` carries no
      # `with_deleted` scope, so a deleted card reads back as nil and a refund
      # or void on a past order would lose the source it needs. Erasing the
      # name is what this step is for; hiding the row would break the ledger
      # the rest of the flow is preserving.
      def anonymize_payment_sources
        Spree::CreditCard.where(id: card_ids).update_all(name: REDACTED_NAME, updated_at: Time.current)
      end

      # Cards saved to the account, plus the ones used at guest checkout: those
      # carry no customer and are reachable only through the payment on the
      # order they paid for.
      def card_ids
        payment_card_ids = Spree::Payment.
          where(order_id: owned_purchases(Spree::Order).select(:id),
                source_type: 'Spree::CreditCard').
          pluck(:source_id)

        (customer.credit_cards.ids + payment_card_ids).compact.uniq
      end

      # Drops the local mapping to the customer object the processor holds.
      #
      # This does not delete anything at the gateway — nothing here calls one,
      # and a gateway call belongs outside the transaction. A merchant whose
      # processor agreement requires deletion there does it through the
      # `after_anonymize` hook, which runs with the erased customer in hand.
      def forget_gateway_profiles
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

      # Merchant-defined data about the person: custom field values, the tags
      # staff filed them under, and the lists they built.
      #
      # The access export discloses all three as this person's data, so
      # erasure has to reach them or the two halves disagree about what the
      # store holds. The schema tripwire cannot catch these — a custom field's
      # value lives in a column called `value`, which no PII-shaped name
      # pattern will ever match.
      # The registration on the account itself. Snapshots frozen onto orders
      # stay put — they are part of the invoice, like the address beside them —
      # but the profile copy is live identifying data with nothing keeping it.
      def remove_tax_identifiers
        customer.tax_identifiers.destroy_all if customer.respond_to?(:tax_identifiers)
      end

      def anonymize_merchant_annotations
        customer.custom_fields.destroy_all if customer.respond_to?(:custom_fields)
        customer.tag_list = [] if customer.respond_to?(:tag_list)
        customer.save(validate: false) if customer.changed?
        customer.wishlists.destroy_all
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
          or(with_email(Spree::ConsentRecord, @original_email)).
          update_all(email: nil, ip_address: nil, user_agent: nil, updated_at: Time.current)
      end

      # The requests themselves carry the address they were made from. The
      # record of the request survives — a controller has to be able to show
      # it answered one — but the address on it is the very thing being
      # erased, so it becomes the anonymized one.
      def anonymize_data_requests
        requests = Spree::DataRequest.where(customer_id: customer.id)

        # The export files are the erasure's blind spot: each one is a
        # complete copy of everything being erased, sitting behind a link that
        # stays live for days. Rewriting the row's email would leave the
        # payload itself untouched and still fetchable.
        requests.each do |data_request|
          data_request.export_file.purge_later if data_request.export_file.attached?
        end

        # The token goes too, so a link already emailed stops resolving rather
        # than waiting out its expiry.
        requests.update_all(
          email: customer.email,
          download_token: nil,
          expires_at: nil,
          updated_at: Time.current
        )
      end

      # Matched by email as well as by customer: guest checkout subscribes with
      # `customer: nil`, so the person's address sits in a row that never
      # pointed at an account.
      # Erasure withdraws marketing consent on the person's behalf. That is a
      # consent decision like any other, so it is recorded as one rather than
      # only flipping the column — the row is what the history is read from.
      def record_consent_withdrawal
        return unless @accepted_marketing

        consent_store = store || Spree::Current.store
        # A console or rake caller may have no store in scope. The erasure is
        # the obligation; the note about it is not worth failing one over.
        return if consent_store.nil?

        Spree::ConsentRecord.record!(
          store: consent_store,
          owner: customer,
          purpose: Spree::ConsentRecord::EMAIL_MARKETING,
          source: Spree::ConsentRecord::ANONYMIZATION,
          accepted: false
        )
      end

      def remove_newsletter_subscriptions
        Spree::NewsletterSubscriber.
          where(customer_id: customer.id).
          or(with_email(Spree::NewsletterSubscriber, @original_email)).
          destroy_all
      end

      def stamp_anonymized
        customer.update_columns(anonymized_at: Time.current, updated_at: Time.current)
      end

      # @param address [Spree::Address]
      # @param deleted [Boolean] whether to soft-delete it as well
      def redact_address(address, deleted:)
        attributes = {
          first_name: REDACTED_NAME,
          last_name: REDACTED_NAME,
          address1: REDACTED_NAME,
          address2: nil,
          phone: nil,
          alternative_phone: nil,
          company: nil,
          label: nil,
          latitude: nil,
          longitude: nil,
          postal_code: truncated_postal_code(address.postal_code),
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
      # @param postal_code [String, nil]
      # @return [String, nil]
      def truncated_postal_code(postal_code)
        return nil if postal_code.blank?

        postal_code.to_s.strip.first(2)
      end

      def anonymous_email
        @anonymous_email ||= "anonymized-#{SecureRandom.uuid}@#{REDACTED_DOMAIN}"
      end


    end
  end
end

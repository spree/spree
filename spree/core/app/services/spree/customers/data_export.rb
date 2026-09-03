module Spree
  module Customers
    # Assembles everything a store holds about one person, for GDPR Art. 15
    # (right of access) and Art. 20 (portability).
    #
    # Art. 20 asks for a "structured, commonly used and machine-readable"
    # format, which is why this returns a plain hash destined for JSON rather
    # than the CSV the admin exports use — a customer's data is nested, and
    # flattening orders and their line items into a spreadsheet loses the
    # structure the regulation asks to preserve.
    #
    # Read-only and side-effect free: the caller decides whether the result is
    # streamed, written to a file or attached to a request record.
    class DataExport
      include Spree::PersonalDataMatching

      # @param customer [Spree::Customer]
      # @param store [Spree::Store, nil] narrows store-scoped records
      #   (newsletter subscriptions, consent). Orders are not narrowed — a
      #   subject access request covers everything the controller holds.
      def initialize(customer:, store: nil)
        @customer = customer
        @store = store
      end

      # @return [Hash]
      def call
        {
          account: account,
          marketing_consent: marketing_consent,
          consent_records: consent_records,
          addresses: addresses,
          orders: orders,
          draft_orders: draft_orders,
          order_groups: order_groups,
          carts: carts,
          payment_sources: payment_sources,
          connected_logins: connected_logins,
          store_credits: store_credits,
          gift_cards: gift_cards,
          wishlists: wishlists,
          custom_fields: custom_fields,
          companies: companies,
          tax_identifiers: tax_identifiers,
          exported_at: Time.current.iso8601
        }
      end

      private

      attr_reader :customer, :store

      def account
        {
          id: customer.prefixed_id,
          email: customer.email,
          first_name: customer.first_name,
          last_name: customer.last_name,
          phone: customer.phone,
          selected_locale: customer.selected_locale,
          tags: customer.tag_list.to_a,
          metadata: customer.metadata.presence,
          internal_note: customer.internal_note,
          created_at: customer.created_at&.iso8601,
          anonymized_at: customer.anonymized_at&.iso8601
        }
      end

      def marketing_consent
        {
          accepts_email_marketing: customer.accepts_email_marketing,
          consent_updated_at: customer.email_marketing_consent_updated_at&.iso8601,
          consent_source: customer.email_marketing_consent_source,
          newsletter_subscriptions: newsletter_subscriptions
        }
      end

      # Matched by email as well as by customer, mirroring the anonymizer: a
      # guest sign-up carries no customer id, and an access response that
      # skipped it would omit data the store holds and is about to wipe.
      def newsletter_subscriptions
        scope = Spree::NewsletterSubscriber.
                where(customer_id: customer.id).
                or(with_email(Spree::NewsletterSubscriber, customer.email))
        scope = scope.where(store_id: store.id) if store

        scope.map do |subscriber|
          {
            email: subscriber.email,
            verified_at: subscriber.verified_at&.iso8601,
            created_at: subscriber.created_at&.iso8601
          }
        end
      end

      # The evidence trail behind the booleans above — when each agreement was
      # made, from where, and which document version was shown.
      # Matched by email as well as by owner: guest checkout records consent
      # against the ORDER, so a person who bought before registering has rows
      # that are about them but which this account does not own.
      def consent_records
        scope = Spree::ConsentRecord.
                where(owner_type: customer.class.base_class.to_s, owner_id: customer.id).
                or(with_email(Spree::ConsentRecord, customer.email))
        scope = scope.where(store_id: store.id) if store

        scope.recent_first.map do |record|
          {
            purpose: record.purpose,
            source: record.source,
            accepted: record.accepted,
            email: record.email,
            ip_address: record.ip_address,
            user_agent: record.user_agent,
            recorded_at: record.recorded_at&.iso8601,
            documents: record.documents_list
          }
        end
      end

      # Reads the table rather than `customer.addresses`, which hides
      # soft-deleted rows. An address the person removed is still an address
      # this store holds, and erasure reaches it — so an access response that
      # skipped it would understate what is on file.
      def addresses
        Spree::Address.
          where(owner_type: customer.class.base_class.to_s, owner_id: customer.id).
          map { |address| address_hash(address) }
      end

      # Batched: a long-standing customer's whole order history, its line items
      # and both address snapshots would otherwise be resident at once, beside
      # the hash built from them and the JSON built from that.
      def orders
        exported = []

        owned_purchases(Spree::Order).complete.
          includes(:line_items, :bill_address, :ship_address).find_each do |order|
          exported << {
            number: order.number,
            email: order.email,
            currency: order.currency,
            item_total: order.item_total&.to_s,
            total: order.total&.to_s,
            payment_status: order.payment_status,
            fulfillment_status: order.fulfillment_status,
            completed_at: order.completed_at&.iso8601,
            customer_note: order.customer_note,
            po_number: order.po_number,
            last_ip_address: order.last_ip_address,
            metadata: order.metadata.presence,
            internal_note: order.internal_note,
            billing_address: address_hash(order.bill_address),
            shipping_address: address_hash(order.ship_address),
            line_items: order.line_items.map do |line_item|
              {
                name: line_item.name,
                sku: line_item.sku,
                quantity: line_item.quantity,
                price: line_item.price&.to_s,
                total: line_item.total&.to_s,
                currency: line_item.currency
              }
            end
          }
        end

        exported
      end

      # A checkout split across sellers becomes one order per seller under a
      # group, and the group keeps its own copy of where the whole thing was
      # going.
      def order_groups
        owned_purchases(Spree::OrderGroup).
          includes(:bill_address, :ship_address).map do |group|
          {
            number: group.number,
            email: group.email,
            currency: group.currency,
            metadata: group.metadata.presence,
            billing_address: address_hash(group.bill_address),
            shipping_address: address_hash(group.ship_address),
            created_at: group.created_at&.iso8601
          }
        end
      end

      # An order a staff member started for this person but never placed. It is
      # not an abandoned checkout — those are carts, on their own table — and
      # it holds the same personal data a placed order does.
      def draft_orders
        owned_purchases(Spree::Order).incomplete.
          includes(:line_items, :bill_address, :ship_address).map do |order|
          {
            number: order.number,
            email: order.email,
            currency: order.currency,
            item_total: order.item_total&.to_s,
            customer_note: order.customer_note,
            last_ip_address: order.last_ip_address,
            metadata: order.metadata.presence,
            internal_note: order.internal_note,
            billing_address: address_hash(order.bill_address),
            shipping_address: address_hash(order.ship_address),
            created_at: order.created_at&.iso8601,
            line_items: order.line_items.map do |line_item|
              { name: line_item.name, sku: line_item.sku, quantity: line_item.quantity }
            end
          }
        end
      end

      # Abandoned checkouts are retained data about this person, so an access
      # request has to disclose them. Kept separate from orders: nothing was
      # bought, and listing them together would misrepresent both.
      def carts
        owned_purchases(Spree::Cart).
          includes(:line_items, :bill_address, :ship_address).map do |cart|
          {
            email: cart.email,
            currency: cart.currency,
            item_total: cart.item_total&.to_s,
            customer_note: cart.customer_note,
            last_ip_address: cart.last_ip_address,
            metadata: cart.metadata.presence,
            billing_address: address_hash(cart.bill_address),
            shipping_address: address_hash(cart.ship_address),
            created_at: cart.created_at&.iso8601,
            line_items: cart.line_items.map do |line_item|
              { name: line_item.name, sku: line_item.sku, quantity: line_item.quantity }
            end
          }
        end
      end

      # Card numbers were never stored, so this is the metadata that was: the
      # brand, the last four digits and the expiry a person would recognise.
      def payment_sources
        payment_card_ids = Spree::Payment.
          where(order_id: owned_purchases(Spree::Order).select(:id),
                source_type: 'Spree::CreditCard').
          pluck(:source_id)

        card_ids = (customer.credit_cards.ids + payment_card_ids).compact.uniq

        Spree::CreditCard.where(id: card_ids).map do |card|
          {
            brand: card.cc_type,
            last_digits: card.last_digits,
            name: card.name,
            month: card.month,
            year: card.year,
            metadata: card.metadata.presence,
            created_at: card.created_at&.iso8601
          }
        end
      end

      # Accounts the person linked to sign in with. The tokens are credentials
      # rather than data about them, so only the provider and the identifier it
      # knows them by are disclosed.
      def connected_logins
        customer.identities.map do |identity|
          {
            provider: identity.provider,
            uid: identity.uid,
            created_at: identity.created_at&.iso8601
          }
        end
      end

      def store_credits
        customer.store_credits.map do |credit|
          {
            amount: credit.amount&.to_s,
            amount_used: credit.amount_used&.to_s,
            currency: credit.currency,
            memo: credit.memo,
            created_at: credit.created_at&.iso8601
          }
        end
      end

      def gift_cards
        customer.gift_cards.map do |gift_card|
          {
            amount: gift_card.amount&.to_s,
            amount_used: gift_card.amount_used&.to_s,
            currency: gift_card.currency,
            status: gift_card.status,
            expires_at: gift_card.expires_at&.iso8601,
            created_at: gift_card.created_at&.iso8601
          }
        end
      end

      def wishlists
        # Through to the product: a variant's name delegates to it, so
        # stopping at the variant costs a query per distinct item.
        customer.wishlists.includes(wished_items: { variant: :product }).map do |wishlist|
          {
            name: wishlist.name,
            is_private: wishlist.is_private,
            created_at: wishlist.created_at&.iso8601,
            items: wishlist.wished_items.map do |wished_item|
              { sku: wished_item.variant&.sku, name: wished_item.variant&.name }
            end
          }
        end
      end

      # Merchant-defined fields on the customer. Private ones are included:
      # visibility governs what a storefront renders, not what the subject is
      # entitled to see about themselves.
      def custom_fields
        return [] unless customer.respond_to?(:custom_fields)

        customer.custom_fields.includes(:custom_field_definition).map do |field|
          { key: field.key, value: field.value.to_s }
        end
      end

      # A VAT or business registration on the account identifies the person
      # (or their business) as surely as an address does.
      def tax_identifiers
        return [] unless customer.respond_to?(:tax_identifiers)

        customer.tax_identifiers.map do |identifier|
          {
            kind: identifier.kind,
            value: identifier.value,
            validation_status: identifier.validation_status,
            created_at: identifier.created_at&.iso8601
          }
        end
      end

      def companies
        customer.company_memberships.includes(:company).map do |membership|
          {
            company: membership.company&.name,
            created_at: membership.created_at&.iso8601
          }
        end
      end

      # Everything this person bought, however they were signed in at the time.
      # Mirrors Spree::Customers::Anonymize#owned_purchases: a guest checkout
      # leaves `customer_id` null, so an access response scoped to the account
      # alone would omit history the store still holds — and that erasure will
      # later wipe.
      #
      # @param model [Class]
      # @return [ActiveRecord::Relation]
      def owned_purchases(model)
        rows_about_person(model, email: customer.email, customer_id: customer.id)
      end

      # @param address [Spree::Address, nil]
      # @return [Hash, nil]
      def address_hash(address)
        return nil if address.nil?

        {
          label: address.label,
          first_name: address.first_name,
          last_name: address.last_name,
          company: address.company,
          address1: address.address1,
          address2: address.address2,
          city: address.city,
          state_code: address.state_code,
          state_name: address.state_name,
          postal_code: address.postal_code,
          country_code: address.country_code,
          phone: address.phone
        }
      end
    end
  end
end

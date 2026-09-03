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
          carts: carts,
          payment_sources: payment_sources,
          store_credits: store_credits,
          gift_cards: gift_cards,
          wishlists: wishlists,
          custom_fields: custom_fields,
          companies: companies,
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

      def newsletter_subscriptions
        scope = Spree::NewsletterSubscriber.where(customer_id: customer.id)
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
                or(Spree::ConsentRecord.where(email: customer.email))
        scope = scope.where(store_id: store.id) if store

        scope.recent_first.map do |record|
          {
            purpose: record.purpose,
            source: record.source,
            accepted: record.accepted,
            recorded_at: record.recorded_at&.iso8601,
            documents: record.documents_list
          }
        end
      end

      def addresses
        customer.addresses.map { |address| address_hash(address) }
      end

      # Batched: a long-standing customer's whole order history, its line items
      # and both address snapshots would otherwise be resident at once, beside
      # the hash built from them and the JSON built from that.
      def orders
        exported = []

        customer.orders.complete.includes(:line_items, :bill_address, :ship_address).find_each do |order|
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

      # Abandoned checkouts are retained data about this person, so an access
      # request has to disclose them. Kept separate from orders: nothing was
      # bought, and listing them together would misrepresent both.
      def carts
        scope = Spree::Cart.where(customer_id: customer.id)
        scope = scope.where(store_id: store.id) if store

        scope.includes(:line_items).map do |cart|
          {
            email: cart.email,
            currency: cart.currency,
            item_total: cart.item_total&.to_s,
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
        customer.credit_cards.map do |card|
          {
            brand: card.cc_type,
            last_digits: card.last_digits,
            name: card.name,
            month: card.month,
            year: card.year,
            created_at: card.created_at&.iso8601
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

      def companies
        customer.company_memberships.includes(:company).map do |membership|
          {
            company: membership.company&.name,
            created_at: membership.created_at&.iso8601
          }
        end
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

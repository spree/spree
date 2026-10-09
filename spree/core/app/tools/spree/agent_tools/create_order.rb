module Spree
  module AgentTools
    # Starts a draft order for a customer, with the lines it should hold.
    #
    # Cancelling and completing an order are workflows, so they reach an agent
    # through the workflow allowlist. Creating one is a service — the admin
    # create takes customer, items, addresses and a coupon in a single call —
    # so it is written out here rather than derived.
    #
    # A draft, never a placed order: the merchant reviews it, and completing
    # it is `orders_complete`, its own decision with its own approval.
    class CreateOrder < Spree::AgentTool
      tool_name 'orders_create'
      description 'Start a draft order for a customer, with the items it should hold. ' \
                  'Items name a variant, not a product — search variants to pick one when ' \
                  'a product has several. The order is left as a draft for the merchant to ' \
                  'review; completing it is a separate step.'
      permission 'write_orders'
      mutating!

      param :customer_id, description: "The customer's prefixed id. Either this or email is required."
      param :email, description: 'Email of the person ordering, when they are not an existing customer'
      param :items, type: :array, items: :object, required: true,
                    description: 'Lines to order: [{"variant_id": "variant_k5nR8xLq", "quantity": 3}]'
      param :currency, description: "Three-letter code; the store's own currency when omitted"
      param :customer_note, description: 'A note the merchant wants kept on the order'

      def call(items:, customer_id: nil, email: nil, currency: nil, customer_note: nil)
        return { error: 'Give either a customer_id or an email.' } if customer_id.blank? && email.blank?

        customer = nil
        if customer_id.present?
          customer = find_customer(customer_id)
          return { error: "No customer found for #{customer_id.inspect}." } if customer.nil?
        end

        lines, refusal = resolve_items(items)
        return refusal if refusal

        create(customer: customer, email: email, lines: lines, currency: currency, note: customer_note)
      end

      def summary(arguments)
        count = Array(arguments[:items]).sum { |item| (item[:quantity] || item['quantity'] || 1).to_i }
        who = arguments[:email].presence || arguments[:customer_id]

        "Create a draft order for #{who} with #{count} #{'item'.pluralize(count)}"
      end

      private

      def create(customer:, email:, lines:, currency:, note:)
        result = Spree.order_create_service.call(
          store: context.store,
          customer: customer,
          created_by: context.principal,
          params: {
            email: email.presence || customer&.email,
            currency: currency.presence,
            customer_note: note.presence,
            items: lines
          }.compact
        )

        return { error: failure_message(result) } unless result.success?

        order = result.value
        {
          ok: true,
          id: order.prefixed_id,
          number: order.number,
          status: order.status,
          item_count: order.line_items.sum(&:quantity),
          total: order.display_total.to_s,
          dashboard_path: ResourceMap.find('orders')&.dashboard_path_for(order)
        }
      end

      # A product has variants, and only a variant can be ordered. Naming the
      # product instead is the mistake a model makes most here, so it is
      # answered with the variants to choose between rather than a refusal
      # the model cannot act on.
      def resolve_items(items)
        rows = Array(items).map { |item| item.respond_to?(:to_h) ? item.to_h.symbolize_keys : {} }
        return [nil, { error: 'Give at least one item.' }] if rows.empty?

        resolved = rows.map do |row|
          id = row[:variant_id].presence
          return [nil, { error: 'Every item needs a variant_id.' }] if id.blank?

          variant = find_variant(id)
          return [nil, variant_refusal(id)] if variant.nil?

          { variant_id: variant.id, quantity: [(row[:quantity] || 1).to_i, 1].max }
        end

        [resolved, nil]
      end

      def find_customer(id)
        context.accessible(Spree.customer_class.for_store(context.store), :show).find_by_prefix_id(id)
      rescue StandardError
        nil
      end

      def find_variant(id)
        context.accessible(Spree::Variant.for_store(context.store), :show).find_by_prefix_id(id)
      rescue StandardError
        nil
      end

      # Where the id names a product, list its variants: that is the one extra
      # step the model needs, and it already has permission to read them.
      def variant_refusal(id)
        product = begin
          context.accessible(Spree::Product.for_store(context.store), :show).find_by_prefix_id(id)
        rescue StandardError
          nil
        end
        return { error: "No variant found for #{id.inspect}." } if product.nil?

        {
          error: "#{id.inspect} is a product, and an order holds variants. " \
                 "#{product.name} has #{product.variants.count} to choose from.",
          variants: product.variants.map do |variant|
            { id: variant.prefixed_id, label: variant.options_text.presence || variant.sku }
          end
        }
      end

      def failure_message(result)
        error = result.error
        message = error.try(:value).is_a?(String) ? error.value : error.to_s

        message.presence || 'The order could not be created.'
      end
    end
  end
end

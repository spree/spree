module Spree
  module Emails
    # Where a returns email sends the customer: their account's order page
    # when the order belongs to an account, or the guest order page with the
    # order token, which is how a guest opens an order without signing in.
    #
    # Built in the mailer and never serialized: the token opens the order.
    module OrderPageUrl
      private

      def order_page_url(order)
        base = current_store.storefront_url
        return URI.join(base, "/account/orders/#{order.prefixed_id}").to_s if order.customer_id.present?

        guest_order_url(order)
      end

      def guest_order_url(order)
        append_token(URI.join(current_store.storefront_url, "/orders/#{order.prefixed_id}").to_s, order.token)
      end

      def return_policy_url
        URI.join(current_store.storefront_url, '/policies/return-policy').to_s
      end

      # Sends a return or exchange email: the record and its order as the
      # template reads them, with the links built here because one carries
      # the order token.
      def deliver_post_sale_email(record, key, serializer, **assigns)
        @order = record.order
        @current_store = record.store || Spree::Store.default

        with_store_locale(current_store, @order.locale) do
          mail_template(
            {
              key => email_data(record, serializer),
              order: email_data(@order, Spree::Emails::OrderSerializer),
              order_url: order_page_url(@order),
              policy_url: return_policy_url
            }.merge(assigns),
            to: @order.email, store_url: current_store.storefront_url
          )
        end
      end
    end
  end
end

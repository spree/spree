module Spree
  # Tells a seller what just happened to them on the marketplace.
  #
  # Deliberately seller-facing only: the legacy module also copied every store
  # admin on approvals and onboarding, which on a marketplace with many sellers
  # is a lot of mail about something staff can already see in the dashboard.
  # Marketplace-side notifications ride the event and webhook surface instead.
  class SellerMailer < BaseMailer
    # @param seller [Spree::Seller, Integer]
    def approved_email(seller)
      @seller = load_seller(seller)
      # Where the seller signs in. Resolved rather than built from the store URL
      # so a hosted dashboard, a dev Vite server and a mounted build all work.
      @dashboard_url = Spree::Stores::DashboardUrl.call(store: store).presence

      deliver_to_seller
    end

    # Carries no reason: the operator's note is an internal record, and a
    # suspended seller is told to get in touch rather than handed a verdict.
    def suspended_email(seller)
      @seller = load_seller(seller)

      deliver_to_seller
    end

    def rejected_email(seller)
      @seller = load_seller(seller)

      deliver_to_seller
    end

    private

    def load_seller(seller)
      seller.respond_to?(:id) ? seller : Spree::Seller.find(seller)
    end

    def store
      @store ||= @seller.store || Spree::Store.default
    end

    # The team plus the address the seller gave for contact — before anyone has
    # accepted an invitation the team is empty, and that address is the only way
    # to reach them.
    def recipients
      (@seller.users.pluck(:email) << @seller.contact_email).compact_blank.uniq(&:downcase)
    end

    def deliver_to_seller
      addresses = recipients
      return message.perform_deliveries = false if addresses.empty?

      @current_store = store
      with_store_locale(store) do
        mail_template(
          { seller: email_data(@seller, Spree.api.seller_serializer), dashboard_url: @dashboard_url },
          to: addresses, store_url: store.storefront_url
        )
      end
    end
  end
end

module Spree
  # Tells a seller what just happened to them on the marketplace.
  #
  # Deliberately seller-facing only: the legacy module also copied every store
  # admin on approvals and onboarding, which on a marketplace with many sellers
  # is a lot of mail about something staff can already see in the dashboard.
  # Marketplace-side notifications ride the event and webhook surface instead.
  class SellerMailer < BaseMailer
    helper Spree::MailHelper

    # @param seller [Spree::Seller, Integer]
    def approved_email(seller)
      @seller = load_seller(seller)
      # Where the seller signs in. Resolved rather than built from the store URL
      # so a hosted dashboard, a dev Vite server and a mounted build all work.
      @dashboard_url = Spree::Stores::DashboardUrl.call(store: store).presence

      deliver_to_seller('seller_mailer.approved_email.subject')
    end

    # Carries no reason: the operator's note is an internal record, and a
    # suspended seller is told to get in touch rather than handed a verdict.
    def suspended_email(seller)
      @seller = load_seller(seller)

      deliver_to_seller('seller_mailer.suspended_email.subject')
    end

    def rejected_email(seller)
      @seller = load_seller(seller)

      deliver_to_seller('seller_mailer.rejected_email.subject')
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

    # Takes the key, not the translated string: resolving the subject outside
    # the block would render it in whatever locale the job happens to run
    # under, so a seller could get an English subject over a German email.
    def deliver_to_seller(subject_key)
      addresses = recipients
      return message.perform_deliveries = false if addresses.empty?

      with_store_locale(store) do
        mail(
          to: addresses,
          subject: Spree.t(subject_key, store_name: store.name),
          store_url: store.storefront_url
        )
      end
    end
  end
end

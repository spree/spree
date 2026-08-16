module Spree
  # Tells a seller what just happened to them on the marketplace.
  #
  # Deliberately vendor-facing only: the legacy module also copied every store
  # admin on approvals and onboarding, which on a marketplace with many sellers
  # is a lot of mail about something staff can already see in the dashboard.
  # Marketplace-side notifications ride the event and webhook surface instead.
  class VendorMailer < BaseMailer
    helper Spree::MailHelper

    # @param vendor [Spree::Vendor, Integer]
    def approved_email(vendor)
      @vendor = load_vendor(vendor)
      # Where the seller signs in. Resolved rather than built from the store URL
      # so a hosted dashboard, a dev Vite server and a mounted build all work.
      @dashboard_url = Spree::Stores::DashboardUrl.call(store: store).presence

      deliver_to_vendor('vendor_mailer.approved_email.subject')
    end

    # Carries no reason: the operator's note is an internal record, and a
    # suspended seller is told to get in touch rather than handed a verdict.
    def suspended_email(vendor)
      @vendor = load_vendor(vendor)

      deliver_to_vendor('vendor_mailer.suspended_email.subject')
    end

    def rejected_email(vendor)
      @vendor = load_vendor(vendor)

      deliver_to_vendor('vendor_mailer.rejected_email.subject')
    end

    private

    def load_vendor(vendor)
      vendor.respond_to?(:id) ? vendor : Spree::Vendor.find(vendor)
    end

    def store
      @store ||= @vendor.store || Spree::Store.default
    end

    # The team plus the address the vendor gave for contact — before anyone has
    # accepted an invitation the team is empty, and that address is the only way
    # to reach them.
    def recipients
      (@vendor.users.pluck(:email) << @vendor.contact_email).compact_blank.uniq(&:downcase)
    end

    # Takes the key, not the translated string: resolving the subject outside
    # the block would render it in whatever locale the job happens to run
    # under, so a seller could get an English subject over a German email.
    def deliver_to_vendor(subject_key)
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

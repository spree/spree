# Shared helpers for ActionMailer previews. Everything here is in-memory (never
# saved) so opening a mailer preview stays read-only.
module Spree
  module PreviewData
    # Include in ActionMailer::Preview subclasses to read the preview toolbar's
    # locale dropdown (`?locale=`). The toolbar sends uppercase codes ("DE"),
    # Spree locales are lowercase.
    module LocaleParam
      private

      def locale
        @params[:locale]&.downcase
      end
    end

    module_function

    # An admin user for previews that need `user.email` / `user.first_name`.
    # Falls back to an unsaved instance when the database has no admin users.
    def admin_user
      Spree.admin_user_class.first ||
        Spree.admin_user_class.new(email: 'admin@example.com', first_name: 'Alex', last_name: 'Doe')
    end

    # A customer for previews of customer-facing account emails. Falls back to
    # an unsaved instance when the database has no users.
    def customer
      Spree.user_class.first ||
        Spree.user_class.new(email: 'customer@example.com').tap do |user|
          user.first_name = 'Alex' if user.respond_to?(:first_name=)
        end
    end

    # The store previews render for. When the preview toolbar's locale dropdown
    # sets `?locale=`, return an unsaved copy of the default store with that
    # `default_locale`, so mailers that render in `store.default_locale` honour
    # the toggle without mutating the real store.
    #
    # @param locale [String, Symbol, nil] the `?locale=` param
    # @return [Spree::Store]
    def store(locale = nil)
      store = Spree::Store.default
      return store if locale.blank? || store.nil?

      dup = store.dup
      dup.id = store.id # keep prefixed-id / URL helpers working
      dup.default_locale = locale.to_s.downcase
      dup.readonly!
      dup
    end
  end
end

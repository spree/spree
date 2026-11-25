module Spree
  # Security notices about a store's API keys, sent to its admins.
  class ApiKeyMailer < BaseMailer
    # Tells one store admin that a secret (Admin API) key was created.
    #
    # @param api_key [Spree::ApiKey]
    # @param admin_user [Object] the admin to notify
    def secret_key_created(api_key, admin_user)
      @current_store = api_key.store

      with_store_locale(@current_store, staff_locale(admin_user, @current_store)) do
        mail_template(
          {
            api_key: email_data(api_key, Spree::Emails::ApiKeySerializer),
            user: email_data(admin_user, Spree::Emails::UserSerializer),
            review_url: "#{Spree::Stores::DashboardUrl.call(store: @current_store)}/#{@current_store.prefixed_id}/settings/api-keys"
          },
          to: admin_user.email, store_url: @current_store.formatted_url
        )
      end
    end
  end
end

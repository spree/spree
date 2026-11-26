module Spree
  # Security notices about a store's API keys, sent to its admins.
  class ApiKeyMailer < BaseMailer
    IP_ADDRESS = 'created_by_ip_address'.freeze

    # The key as the email shows it, taken when the key is created. The notice
    # is sent from this copy rather than the record, so deleting the key
    # before the job runs cannot suppress it. The IP stays encrypted while the
    # copy waits in the job queue.
    #
    # @param api_key [Spree::ApiKey]
    # @return [Hash]
    def self.notice_for(api_key)
      notice = Spree::Emails::TemplateData.call(api_key, Spree::Emails::ApiKeySerializer, store: api_key.store)
      notice.merge(IP_ADDRESS => encrypt_ip_address(notice[IP_ADDRESS]))
    end

    # Tells one store admin that a secret (Admin API) key was created.
    #
    # @param store [Spree::Store] the key's store
    # @param notice [Hash] from {.notice_for}
    # @param admin_user [Object] the admin to notify
    def secret_key_created(store, notice, admin_user)
      @current_store = store

      with_store_locale(store, staff_locale(admin_user, store)) do
        mail_template(
          {
            api_key: notice.merge(IP_ADDRESS => self.class.decrypt_ip_address(notice[IP_ADDRESS])),
            user: email_data(admin_user, Spree::Emails::UserSerializer),
            review_url: "#{Spree::Stores::DashboardUrl.call(store: store)}/#{store.prefixed_id}/settings/api-keys"
          },
          to: admin_user.email, store_url: store.formatted_url
        )
      end
    end

    # Encrypted the same way as Spree::ApiKey#created_by_ip_address: only when
    # Active Record encryption keys are configured.
    def self.encrypt_ip_address(value)
      return value if value.blank? || !ActiveRecord::Encryption.config.has_primary_key?

      ActiveRecord::Encryption.encryptor.encrypt(value)
    end

    def self.decrypt_ip_address(value)
      return value if value.blank? || !ActiveRecord::Encryption.config.has_primary_key?

      ActiveRecord::Encryption.encryptor.decrypt(value)
    end
  end
end

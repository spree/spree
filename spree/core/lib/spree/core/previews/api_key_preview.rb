require_relative 'preview_data'

module Spree
  # Preview Spree API key security emails at /rails/mailers/spree/api_key
  class ApiKeyPreview < ActionMailer::Preview
    include Spree::PreviewData::LocaleParam

    def secret_key_created
      Spree::ApiKeyMailer.secret_key_created(example_key, Spree::PreviewData.admin_user, ip_address: '203.0.113.42')
    end

    private

    # Unsaved, so opening the preview never mints a credential.
    def example_key
      Spree::ApiKey.new(
        store: Spree::PreviewData.store(locale),
        name: 'Warehouse integration',
        key_type: 'secret',
        token_prefix: 'sk_8Hd2kQpZ',
        scopes: %w[read_orders write_products],
        created_by: Spree::PreviewData.admin_user,
        created_at: Time.current
      )
    end
  end
end

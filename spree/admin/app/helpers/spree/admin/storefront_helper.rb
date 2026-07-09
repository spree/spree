# frozen_string_literal: true

module Spree
  module Admin
    module StorefrontHelper
      STOREFRONT_REPOSITORY_URL = 'https://github.com/spree/storefront'

      # Builds the Vercel deploy-button URL for the storefront starter, prefilled
      # with the store's API URL and publishable key (both non-secret), and
      # redirecting back to the admin storefront page after a successful deploy
      # so the deployed domain can be added as an allowed origin.
      #
      # @param store [Spree::Store]
      # @param api_key [Spree::ApiKey] an active publishable key
      # @return [String]
      def vercel_deploy_url(store, api_key)
        query = {
          'repository-url' => STOREFRONT_REPOSITORY_URL,
          'project-name' => "#{store.code}-storefront",
          'repository-name' => "#{store.code}-storefront",
          'env' => 'SPREE_API_URL,SPREE_PUBLISHABLE_KEY',
          'envDefaults' => {
            'SPREE_API_URL' => store.formatted_url,
            'SPREE_PUBLISHABLE_KEY' => api_key.token
          }.to_json,
          'envDescription' => Spree.t('admin.storefront_setup.env_description'),
          'envLink' => "#{STOREFRONT_REPOSITORY_URL}#readme",
          'redirect-url' => spree.admin_storefront_url
        }

        "https://vercel.com/new/clone?#{query.to_query}"
      end

      # True when the store's public URL points at a loopback host, which
      # Vercel's build servers cannot reach.
      #
      # @param store [Spree::Store]
      # @return [Boolean]
      def store_url_loopback?(store = current_store)
        Spree::AllowedOrigin::LOOPBACK_HOSTS.include?(
          Spree::AllowedOrigin.parse_origin(store.formatted_url)&.dig(:host)
        )
      end
    end
  end
end

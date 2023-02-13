require 'pry'

module Spree
  class WelcomePageController < Spree::BaseController
    def index
      if Spree::Core::Engine.backend_available?
        @admin_page_link = "#{current_store.url}:#{request.port}/admin"
      else
        @admin_page_link = nil
      end
      @customize_spree_link = 'https://dev-docs.spreecommerce.org/customization/'
      @install_frontend_link = 'https://dev-docs.spreecommerce.org/storefronts'
      if Spree::Core::Engine.api_available?
        @spree_api_link = 'https://api.spreecommerce.org/'
      else
        @spree_api_link = nil
      end
      @slack_invite = 'https://slack.spreecommerce.org'
      @github_link = 'https://github.com/spree'
    end
  end
end

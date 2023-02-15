module Spree
  class WelcomePageController < Spree::BaseController
    CUSTOMIZE_SPREE_LINK = 'https://dev-docs.spreecommerce.org/customization/'.freeze
    SLACK_INVITE = 'https://slack.spreecommerce.org'.freeze
    INSTALL_FRONTEND_LINK = 'https://dev-docs.spreecommerce.org/storefronts'.freeze
    GITHUB_LINK = 'https://github.com/spree'.freeze

    def index
      @admin_page_link = Spree::Core::Engine.backend_available? ? 'admin' : nil
      @spree_api_link = Spree::Core::Engine.api_available? ? 'https://api.spreecommerce.org/' : nil
    end
  end
end

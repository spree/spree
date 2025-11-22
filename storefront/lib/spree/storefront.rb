require 'spree_core'

require 'active_link_to'
require 'canonical-rails'
require 'heroicon'
require 'importmap-rails'
require 'local_time'
require 'mail_form'
require 'stimulus-rails'
require 'tailwindcss-rails'
require 'turbo-rails'
require 'inline_svg'

require 'spree/storefront/engine'
require 'spree/core/partials'

module Spree
  def self.storefront
    @storefront ||= StorefrontConfig.new
  end

  class StorefrontConfig
    def partials
      @partials ||= Spree::Core::Partials.new(
        Rails.application.config.spree_storefront,
        Spree::Storefront::Engine::Environment
      )
    end
  end

  module Storefront
  end
end

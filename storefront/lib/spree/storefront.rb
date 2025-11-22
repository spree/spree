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
  module Storefront
    def self.partials
      @partials ||= Spree::Core::Partials.new(
        Rails.application.config.spree_storefront,
        Spree::Storefront::Engine::Environment
      )
    end
  end
end

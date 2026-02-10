require 'spree'

require 'active_link_to'
require 'breadcrumbs_on_rails'
require 'chartkick'
require 'groupdate'
require 'hightop'
require 'importmap-rails'
require 'mapkick-rb'
require 'turbo-rails'
require 'stimulus-rails'
require 'local_time'
require 'tailwindcss-rails'
require 'inline_svg'

require 'spree/admin/action_callbacks'
require 'spree/admin/callbacks'
require 'spree/admin/engine'
require 'spree/core/partials'

require 'tinymce-rails'
require 'pagy'

module Spree
  def self.admin
    @admin ||= AdminConfig.new
  end

  class AdminConfig
    def partials
      @partials ||= Spree::Core::Partials.new(
        Rails.application.config.spree_admin,
        Spree::Admin::Engine::Environment
      )
    end

    def navigation
      Rails.application.config.spree_admin.navigation
    end

    def tables
      Rails.application.config.spree_admin.tables
    end
  end
end

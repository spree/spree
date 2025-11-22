require 'spree_core'
require 'spree_api'

require 'active_link_to'
require 'breadcrumbs_on_rails'
require 'chartkick'
require 'groupdate'
require 'hightop'
require 'importmap-rails'
require 'mapkick-rb'
require 'bootstrap'
require 'turbo-rails'
require 'stimulus-rails'
require 'local_time'
require 'dartsass-rails'
require 'inline_svg'

require 'spree/admin/action_callbacks'
require 'spree/admin/callbacks'
require 'spree/admin/engine'

require 'tinymce-rails'

module Spree
  module Admin
    def self.navigation
      Rails.application.config.spree_admin.navigation
    end

    def self.navigation=(navigation)
      Rails.application.config.spree_admin.navigation = navigation
    end
  end
end

module Spree
  module Api
    module V2
      module Platform
        class IconSerializer < BaseSerializer
          set_type :icon

          attribute :url do |icon|
            url_helpers = Rails.application.routes.url_helpers
            url_helpers.polymorphic_url(icon.attachment, only_path: true)
          end
        end
      end
    end
  end
end

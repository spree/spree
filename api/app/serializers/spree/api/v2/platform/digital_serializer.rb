module Spree
  module Api
    module V2
      module Platform
        class DigitalSerializer < BaseSerializer
          set_type :digital

          attributes :attachment_file_name, :attachment_file_size, :attachment_content_type

          attribute :url do |digital|
            url_helpers = Rails.application.routes.url_helpers
            url_helpers.polymorphic_url(digital.attachment, only_path: true)
          end

          belongs_to :variant
        end
      end
    end
  end
end

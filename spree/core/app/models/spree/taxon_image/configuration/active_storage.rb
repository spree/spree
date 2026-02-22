module Spree
  class TaxonImage < Asset
    module Configuration
      module ActiveStorage
        extend ActiveSupport::Concern

        included do
          validates :attachment, content_type: Rails.application.config.active_storage.web_image_content_types

          default_scope { includes(attachment_attachment: :blob) }

          def self.styles
            @styles ||= {
              mini: '32x32>',
              normal: '128x128>'
            }
          end

          def default_style
            :mini
          end
        end
      end
    end
  end
end

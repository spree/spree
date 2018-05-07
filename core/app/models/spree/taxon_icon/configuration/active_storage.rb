module Spree
  class TaxonIcon < Asset
    module Configuration
      module ActiveStorage
        extend ActiveSupport::Concern
        include Spree::AttachmentValidation

        included do
          validate :check_attachment_content_type

          has_one_attached :attachment

          def self.styles
            @styles ||= {
              mini:   '32x32>',
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

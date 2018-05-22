module Spree
  class Asset < Spree::Base
    module Support
      module ActiveStorage
        extend ActiveSupport::Concern

        included do
          def url(style)
            return placeholder(style) unless attachment.attached?

            attachment.variant(resize: dimensions_for_style(style))
          end

          def placeholder(style)
            "noimage/#{style}.png"
          end

          def dimensions_for_style(style)
            self.class.styles.with_indifferent_access[style] || default_style
          end
        end
      end
    end
  end
end

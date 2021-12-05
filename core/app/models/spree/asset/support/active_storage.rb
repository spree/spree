module Spree
  class Asset < Spree::Base
    module Support
      module ActiveStorage
        extend ActiveSupport::Concern

        included do
          def url(style)
            return placeholder(style) unless attachment.attached?

            attachment.variant(resize_to_limit: dimensions_for_style(style))
          end

          def placeholder(style)
            "noimage/#{style}.png"
          end

          def dimensions_for_style(style)
            dimensions = self.class.styles.with_indifferent_access[style] || self.class.styles.with_indifferent_access[default_style]
            dimensions.split('x').map(&:to_i)
          end
        end
      end
    end
  end
end

module Spree
  module Api
    module V3
      module Store
        class DigitalLinkSerializer < BaseSerializer
          attributes :id, :access_counter, :authorizable, :expired, :access_limit_exceeded,
                     :filename, :content_type

          attribute :authorizable do |digital_link|
            digital_link.authorizable?
          end

          attribute :expired do |digital_link|
            digital_link.expired?
          end

          attribute :access_limit_exceeded do |digital_link|
            digital_link.access_limit_exceeded?
          end
        end
      end
    end
  end
end

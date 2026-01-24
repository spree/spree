module Spree
  module Api
    module V3
      class DigitalLinkSerializer < BaseSerializer
        typelize access_counter: :number, filename: :string, content_type: :string,
                 authorizable: :boolean, expired: :boolean, access_limit_exceeded: :boolean

        attributes :access_counter, :filename, :content_type,
                   created_at: :iso8601, updated_at: :iso8601

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

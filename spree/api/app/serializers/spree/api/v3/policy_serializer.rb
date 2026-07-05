module Spree
  module Api
    module V3
      class PolicySerializer < BaseSerializer
        typelize name: :string, slug: :string,
                 body: [:string, nullable: true], body_html: [:string, nullable: true]

        attributes :name, :slug

        attribute :body do |policy|
          policy.body&.to_plain_text
        end

        attribute :body_html do |policy|
          policy.body&.body&.to_s.to_s
        end

      end
    end
  end
end

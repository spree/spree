module Spree
  module Api
    module V3
      class PolicySerializer < BaseSerializer
        typelize name: :string, slug: :string,
                 body: [:string, nullable: true], body_html: [:string, nullable: true]

        attributes :name, :slug

        attribute :body do |policy|
          Spree::RichTextHelper.to_plain_text(policy.body)
        end

        attribute :body_html do |policy|
          policy.body_html
        end

      end
    end
  end
end

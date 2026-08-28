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

        # The one timestamp a store serializer carries. When a legal document
        # last changed is what a shopper is entitled to see on the page —
        # "last updated" is the convention for policies — not operational
        # detail. `created_at` stays admin-only.
        attributes updated_at: :iso8601
      end
    end
  end
end

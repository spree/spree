module Spree
  module V2
    module Storefront
      class PolicySerializer < BaseSerializer
        set_type :policy

        attributes :name, :slug, :show_in_checkout_footer, :created_at, :updated_at

        attribute :body do |object|
          object.body.to_plain_text
        end

        attribute :body_html do |object|
          object.body.to_s.html_safe
        end
      end
    end
  end
end

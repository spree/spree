module Spree
  module V2
    module Storefront
      class PolicySerializer < BaseSerializer
        set_type :policy

        attributes :name, :locale, :created_at, :updated_at

        attribute :body_plain_text do |object|
          object.to_plain_text
        end

        attribute :body_html do |object|
          object.to_html
        end
      end
    end
  end
end

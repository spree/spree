# frozen_string_literal: true

module Spree
  module Api
    module V3
      module Admin
        # Coupon codes belong to multi-code promotions. Read-only here:
        # codes are generated server-side based on the promotion's
        # `code_prefix` + `number_of_codes`.
        class CouponCodeSerializer < BaseSerializer
          typelize code: :string,
                   state: [:string, nullable: true],
                   promotion_id: :string,
                   order_id: [:string, nullable: true]

          attributes :code, :state,
                     created_at: :iso8601, updated_at: :iso8601

          attribute :promotion_id do |coupon|
            coupon.promotion&.prefixed_id
          end

          attribute :order_id do |coupon|
            coupon.order&.prefixed_id
          end
        end
      end
    end
  end
end

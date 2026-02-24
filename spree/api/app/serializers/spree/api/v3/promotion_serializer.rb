# frozen_string_literal: true

module Spree
  module Api
    module V3
      class PromotionSerializer < BaseSerializer
        typelize name: :string, description: [:string, nullable: true],
                 code: [:string, nullable: true], type: [:string, nullable: true],
                 kind: [:string, nullable: true], path: [:string, nullable: true],
                 match_policy: [:string, nullable: true], usage_limit: [:number, nullable: true],
                 advertise: :boolean, multi_codes: :boolean,
                 code_prefix: [:string, nullable: true], number_of_codes: [:number, nullable: true],
                 starts_at: [:string, nullable: true], expires_at: [:string, nullable: true],
                 promotion_category_id: [:string, nullable: true]

        attributes :name, :description, :code, :type, :kind, :path,
                   :match_policy, :usage_limit, :advertise, :multi_codes,
                   :code_prefix, :number_of_codes,
                   starts_at: :iso8601, expires_at: :iso8601,
                   created_at: :iso8601, updated_at: :iso8601

        attribute :promotion_category_id do |promotion|
          promotion.promotion_category&.prefixed_id
        end
      end
    end
  end
end

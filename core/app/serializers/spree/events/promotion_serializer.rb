# frozen_string_literal: true

module Spree
  module Events
    class PromotionSerializer < BaseSerializer
      protected

      def attributes
        {
          id: public_id(resource),
          name: resource.name,
          description: resource.description,
          code: resource.code,
          type: resource.type,
          kind: resource.kind,
          path: resource.path,
          match_policy: resource.match_policy,
          usage_limit: resource.usage_limit,
          advertise: resource.advertise,
          multi_codes: resource.multi_codes,
          code_prefix: resource.code_prefix,
          number_of_codes: resource.number_of_codes,
          starts_at: timestamp(resource.starts_at),
          expires_at: timestamp(resource.expires_at),
          promotion_category_id: public_id(resource.promotion_category),
          created_at: timestamp(resource.created_at),
          updated_at: timestamp(resource.updated_at)
        }
      end
    end
  end
end

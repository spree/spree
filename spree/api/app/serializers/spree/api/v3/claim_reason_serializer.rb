# frozen_string_literal: true

module Spree
  module Api
    module V3
      # What went wrong with a delivery. Embedded in claims so a customer sees
      # the reason's name rather than only its id; the vocabulary itself has
      # no Store API controller of its own.
      #
      # Parallel to ReturnReasonSerializer rather than sharing a base class:
      # Typelizer emits one TS type per serializer, so a shared parent would
      # publish an abstract `Reason` type that no endpoint returns.
      class ClaimReasonSerializer < BaseSerializer
        typelize name: :string, active: :boolean

        attributes :name, :active
      end
    end
  end
end

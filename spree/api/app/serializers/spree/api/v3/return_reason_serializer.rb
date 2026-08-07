# frozen_string_literal: true

module Spree
  module Api
    module V3
      # Why a customer sent something back. Embedded in returns and exchanges
      # so a customer sees the reason's name rather than only its id; the
      # vocabulary itself has no Store API controller of its own.
      #
      # Parallel to ClaimReasonSerializer rather than sharing a base class:
      # Typelizer emits one TS type per serializer, so a shared parent would
      # publish an abstract `Reason` type that no endpoint returns.
      class ReturnReasonSerializer < BaseSerializer
        typelize name: :string, active: :boolean

        attributes :name, :active
      end
    end
  end
end

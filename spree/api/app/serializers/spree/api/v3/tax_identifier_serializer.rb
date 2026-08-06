module Spree
  module Api
    module V3
      # The buyer's own tax registration. Deliberately just the kind and the
      # number: the validation verdict is the platform's bookkeeping, and showing
      # a customer that their number came back unverified invites support
      # tickets about a check they cannot influence.
      class TaxIdentifierSerializer < BaseSerializer
        typelize kind: :string, value: :string

        attributes :kind, :value
      end
    end
  end
end

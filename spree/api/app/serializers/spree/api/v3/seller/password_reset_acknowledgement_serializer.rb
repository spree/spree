module Spree
  module Api
    module V3
      module Seller
        # The answer to a password reset request. It reads the same whether
        # or not an account matched, so it reveals nothing about who exists.
        class PasswordResetAcknowledgementSerializer
          include Alba::Resource
          include Typelizer::DSL

          typelize message: :string

          attributes :message
        end
      end
    end
  end
end

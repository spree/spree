module Spree
  class ReturnAuthorizationReason < Spree::Base
    include Spree::NamedType

    has_many :return_authorizations
  end
end

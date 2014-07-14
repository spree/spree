module Spree
  class ReturnAuthorizationReason < Spree::Base
    include Spree::ReasonType

    has_many :return_authorizations
  end
end

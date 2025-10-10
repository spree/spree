module Spree
  class ReturnAuthorizationReason < Spree.base_class
    include Spree::NamedType

    has_many :return_authorizations, dependent: :restrict_with_error
  end
end

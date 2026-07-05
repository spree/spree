module Spree
  class ReturnAuthorizationReason < Spree.base_class
    has_prefix_id :rar

    include Spree::NamedType

    has_many :return_authorizations, dependent: :restrict_with_error
  end
end

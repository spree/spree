module Spree
  # One exemption reason a merchant may record on a certificate: the code the
  # tax engine reads, and the words the merchant reads.
  class TaxExemptionReasonCode
    include ActiveModel::Model
    include ActiveModel::Attributes

    attribute :value, :string
    attribute :label, :string
  end
end

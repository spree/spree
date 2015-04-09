module Spree
  class AdjustmentSerializer < ActiveModel::Serializer
    attributes :amount , :label , :mandatory , :eligible,
               :created_at , :updated_at , :state , :included
  end
end

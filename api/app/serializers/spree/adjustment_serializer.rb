module Spree
  class AdjustmentSerializer < ActiveModel::Serializer
    # attributes *Spree::Api::ApiHelpers.adjustment_attributes
    attributes :amount , :label , :mandatory , :eligible,
               :created_at , :updated_at , :state , :included
  end
end

module Spree::RansackableAttributes
  extend ActiveSupport::Concern
  included do
    class_attribute :whitelisted_ransackable_associations
    class_attribute :whitelisted_ransackable_attributes
    class_attribute :whitelisted_ransackable_scopes

    class_attribute :default_ransackable_attributes
    self.default_ransackable_attributes = %w[id name updated_at created_at]

    def self.ransackable_associations(*_args)
      base = whitelisted_ransackable_associations || []
      base | Spree.ransack.custom_associations_for(self)
    end

    def self.ransackable_attributes(*_args)
      base = default_ransackable_attributes | (whitelisted_ransackable_attributes || [])
      base | Spree.ransack.custom_attributes_for(self)
    end

    def self.ransackable_scopes(*_args)
      base = whitelisted_ransackable_scopes || []
      base | Spree.ransack.custom_scopes_for(self)
    end
  end
end

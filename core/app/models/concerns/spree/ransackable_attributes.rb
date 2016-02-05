module Spree::RansackableAttributes
  extend ActiveSupport::Concern
  included do
    class_attribute :whitelisted_ransackable_associations
    class_attribute :whitelisted_ransackable_attributes

    class_attribute :default_ransackable_attributes
    self.default_ransackable_attributes = %w[id name]

    def self.ransackable_associations(*args)
      self.whitelisted_ransackable_associations || []
    end

    def self.ransackable_attributes(*args)
      self.default_ransackable_attributes | (self.whitelisted_ransackable_attributes || [])
    end
  end

end

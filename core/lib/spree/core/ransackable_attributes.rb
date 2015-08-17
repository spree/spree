ActiveRecord::Base.class_eval do
  class_attribute :whitelisted_ransackable_associations
  class_attribute :whitelisted_ransackable_attributes

  class_attribute :default_ransackable_attributes
  self.default_ransackable_attributes = %w[id name]

  def self.ransackable_associations *arg
    self.whitelisted_ransackable_associations || []
  end

  def self.ransackable_attributes *arg
    self.default_ransackable_attributes | (self.whitelisted_ransackable_attributes || [])
  end
end

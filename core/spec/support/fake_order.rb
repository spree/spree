require 'active_model'

class FakeOrder
  include ActiveModel::Validations
  include ActiveModel::Validations::Callbacks
  include ActiveModel::AttributeMethods

  def self.fake_association(name, options={})
    attr_accessor name
  end
  class << self
    alias_method :belongs_to, :fake_association
    alias_method :has_many, :fake_association
  end


  def self.accepts_nested_attributes_for(*args)

  end

  def self.attr_accessible(*args)
  end
end

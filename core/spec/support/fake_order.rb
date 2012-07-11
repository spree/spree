require 'active_model'

class FakeOrder
  include ActiveModel::Validations
  include ActiveModel::Validations::Callbacks
  include ActiveModel::AttributeMethods

  def self.belongs_to(name, options={})
    attr_accessor name
  end

  def self.accepts_nested_attributes_for(*args)

  end

  def self.attr_accessible(*args)
  end
end

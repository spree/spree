class Calculator < ActiveRecord::Base
  belongs_to :calculable, :polymorphic => true

  # This method must be overriden in concrete calculator.
  #
  # It should return amount computed based on #calculable and/or optional parameter
  def compute(something=nil)
    raise(NotImplementedError, "please use concrete calculator")
  end

  # overwrite to provide description for your calculators
  def self.description
    "Base Caclulator"
  end

  ###################################################################

  @@calculators = Set.new
  # Registers calculator to be used with selected kinds of operations
  def self.register(*klasses)
    @@calculators.add(self)
    klasses.each do |klass|
      klass = klass.constantize if klass.is_a?(String)
      klass.register_calculator(self)
    end
    self
  end

  # Returns all calculators applicable for kind of work
  # If passed nil, will return only general calculators
  def self.calculators
    @@calculators.to_a
  end

  def to_s
    self.class.name.titleize.gsub("Calculator\/", "")
  end

  def description
    self.class.description
  end

  def available?(object)
    return true #should be overridden if needed
  end
end

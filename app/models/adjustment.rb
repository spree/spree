class Adjustment < ActiveRecord::Base
  acts_as_list :scope => :order
  
  belongs_to :order
  belongs_to :adjustment_source, :polymorphic => true

  validates_presence_of :amount
  validates_presence_of :description
  validates_numericality_of :amount

  before_save do |record|
    new_amount = record.calculate_adjustment
    record.amount = new_amount if new_amount
    record.secondary_type ||= record.type
  end

  def calculate_adjustment
    if adjustment_source
      calc = adjustment_source.calculator || adjustment_source.default_calculator
      raise(RuntimeError, "#{self.class.name}##{id} doesn't have a calculator") unless calc
      calc.compute(adjustment_source)
    elsif read_attribute(:amount)
      read_attribute(:amount)
    else
      nil
    end
  end

  def amount
    read_attribute(:amount) || self.calculate_adjustment
  end
  
  def update_amount
    new_amount = calculate_adjustment
    update_attribute(:amount, new_amount) if new_amount
  end
end

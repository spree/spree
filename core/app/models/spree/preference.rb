class Spree::Preference < ActiveRecord::Base

  validates :key, :presence => true

  def value=(value)
    self[:value] = value
    self[:value_type] = value.class.name
  end

  def value
    return unless self[:value]

    case self[:value_type]
    when Symbol.to_s
      self[:value].to_sym
    when Fixnum.to_s
      self[:value].to_i
    when Bignum.to_s
      self[:value].to_f.to_i
    when Float.to_s
      self[:value].to_f
    when TrueClass.to_s
      true
    when FalseClass.to_s
      false
    else
      self[:value]
    end
  end

end

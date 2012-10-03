class Spree::Preference < ActiveRecord::Base
  attr_accessible :name, :key, :value_type, :value

  validates :key, :presence => true
  validates :value_type, :presence => true

  scope :valid, lambda { where(Spree::Preference.arel_table[:key].not_eq(nil)).where(Spree::Preference.arel_table[:value_type].not_eq(nil)) }

  # The type conversions here should match
  # the ones in spree::preferences::preferrable#convert_preference_value
  def value
    if self[:value_type].present?
      case self[:value_type].to_sym
      when :string, :text
        self[:value].to_s
      when :password
        self[:value].to_s
      when :decimal
        BigDecimal.new(self[:value].to_s).round(2, BigDecimal::ROUND_HALF_UP)
      when :integer
        self[:value].to_i
      when :boolean
        (self[:value].to_s =~ /^[t|1]/i) != nil
      else
        self[:value].is_a?(String) ? YAML.load(self[:value]) : self[:value]
      end
    else
      self[:value]
    end
  end

  def raw_value
    self[:value]
  end

  # For the rc releases of 1.0, we stored the object class names, this converts
  # to preferences definition types. This code should eventually be removed.
  # it is called during the load_preferences of the Preferences::Store
  def self.convert_old_value_types(preference)
    classes =  [Symbol.to_s, Fixnum.to_s, Bignum.to_s,
                Float.to_s, TrueClass.to_s, FalseClass.to_s]
    return unless classes.map(&:downcase).include? preference.value_type.downcase

    case preference.value_type.downcase
    when "symbol"
      preference.value_type = 'string'
    when "fixnum"
      preference.value_type = 'integer'
    when "bignum"
      preference.value_type = 'integer'
      preference.value = preference.value.to_f.to_i
    when "float"
      preference.value_type = 'decimal'
    when "trueclass"
      preference.value_type = 'boolean'
      preference.value = "true"
    when "falseclass"
      preference.value_type = 'boolean'
      preference.value = "false"
    end

    preference.save
  end

end

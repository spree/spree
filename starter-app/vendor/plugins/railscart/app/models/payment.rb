class Payment < ActiveRecord::Base

  def self.columns() @columns ||= []; end
  def self.column(name, sql_type = nil, default = nil, null = true)
    columns << ActiveRecord::ConnectionAdapters::Column.new(name.to_s, default, sql_type.to_s, null)
  end

  class CreditCard < Payment 

    column :cc_number, :string
    column :cc_exp_year, :string
    column :cc_exp_month, :string
    column :cvv, :string


    def cvv_valid?
      self.cvv =~ Format::CVV_REGEX ? true : false
    end

    # This is one way to do a custom validation. 
    def self.validates_credit_card(*attr_names)
      validates_each(attr_names) do |record, attr_name, value|
        unless passes_mod_10?(value.to_s)
          record.errors.add(attr_name, "Credit card expiration month is invalid")
        end
      end
    end

    def self.passes_mod_10?(number)
      return false unless number.to_s.length >= 13
      sum = 0
      for i in 0..number.length
        weight = number[-1 * (i + 2), 1].to_i * (2 - (i % 2))
        sum += (weight < 10) ? weight : weight - 9
      end
      (number[-1,1].to_i == (10 - sum % 10) % 10)
    end


    validates_inclusion_of :cc_exp_year, :in=>%w( 2007 2008 2009 2010 2011 2012 2013 2014 2015 2016 2017 2018 2019 ), :message=>"Credit card expiration year is invalid"
    validates_inclusion_of :cc_exp_month, :in=>%w( 01 02 03 04 05 06 07 08 09 10 11 12 ), :message=>"Credit card expiration month is invalid"
    validates_credit_card :cc_number
  
  end

  class Check < Payment
  end

end

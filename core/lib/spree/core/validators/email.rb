# Borrowed from http://my.rails-royce.org/2010/07/21/email-validation-in-ruby-on-rails-without-regexp/
# Mentioned in tweet here: https://twitter.com/_sohara/status/177120126083141633
require 'mail'
class EmailValidator < ActiveModel::EachValidator
  def validate_each(record,attribute,value)
    unless valid?(value)
      record.errors.add(attribute, :invalid, {:value => value}.merge!(options))
    end
  end

  def valid?(email)
    begin
      m = Mail::Address.new(email)
      # We must check that value contains a domain and that value is an email address
      r = m.domain && m.address == email
      t = m.__send__(:tree)
      # We need to dig into treetop
      # A valid domain must have dot_atom_text elements size > 1
      # user@localhost is excluded
      # treetop must respond to domain
      # We exclude valid email values like <user@localhost.com>
      # Hence we use m.__send__(tree).domain
      r &&= (t.domain.dot_atom_text.elements.size > 1)
    rescue Exception => e
      r = false
    end
    r
  end
end

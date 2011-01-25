# allows creditcard info to be saved to the datbase which is needed for factories to work properly
class TestCard < Creditcard
  def remove_readonly_attributes(attributes) attributes; end
end

Factory.define(:creditcard, :class => TestCard) do |f|
  f.verification_value 123
  f.month 12
  f.year 2013
  f.number "4111111111111111"
end

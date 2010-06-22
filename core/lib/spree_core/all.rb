require "spree"

%w(
  spree_core
  spree_payment_gateway
).each do |extension|
  begin
    require "#{extension}/engine"
    #require "#{framework}/railtie"
  rescue LoadError
  end
end
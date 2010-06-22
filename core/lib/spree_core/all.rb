require "spree"

%w(
  spree_core
  spree_payment_gateway
  spree_api
  spree_dashboard
).each do |extension|
  begin
    require "#{extension}/engine"
    #require "#{framework}/railtie"
  rescue LoadError
  end
end
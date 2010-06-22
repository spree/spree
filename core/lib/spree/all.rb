require "spree"

%w(
  core
  spree_payment_gateway
).each do |extension|
  begin
    require "#{extension}/engine"
    #require "#{framework}/railtie"
  rescue LoadError
  end
end
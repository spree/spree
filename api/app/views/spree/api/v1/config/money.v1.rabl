object false
node(:symbol) { ::Money.new(1, Spree::Config[:currency]).symbol }

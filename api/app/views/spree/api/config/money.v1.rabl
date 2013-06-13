object false
node(:symbol) { ::Money.new(1, Spree::Config[:currency]).symbol }
node(:symbol_position) { Spree::Config[:currency_symbol_position] }
node(:no_cents) { Spree::Config[:hide_cents] }
node(:decimal_mark) { Spree::Config[:currency_decimal_mark] }
node(:thousands_separator) { Spree::Config[:currency_thousands_separator] }
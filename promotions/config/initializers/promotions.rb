# register default promotion calculators
[
  Calculator::FlatPercentItemTotal,
  Calculator::FlatRate,
  Calculator::FlexiRate,
  Calculator::PerItem
].each{|c_model|
  begin
    Promotion.register_calculator(c_model) if c_model.table_exists?
  rescue Exception => e
    $stderr.puts "Error registering promotion calculator #{c_model}"
  end
}

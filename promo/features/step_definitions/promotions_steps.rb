Then /^the existing order should have total at "([^"]*)"$/ do |total|
  Order.first.total.to_f.should == total.to_f
end


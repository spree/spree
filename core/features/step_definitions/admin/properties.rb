Then /^I should see listing properties tabular attributes$/ do
  output = tableish('table#listing_properties tr', 'td,th')
  data = output[0]
  data[0].should == 'Name'
  data[1].should == 'Presentation'

  data = output[1]
  data[0].should == Spree::Property.limit(1).order('name asc').to_a.first.name
end

Given /^"(.*)" prototype has properties "(.*)"$/ do |prototype_name, properties|
  p = Spree::Prototype.create!(:name => prototype_name)
  properties.split(',').each do |property|
    p.properties << Spree::Property.find_by_name(property.strip)
  end
end

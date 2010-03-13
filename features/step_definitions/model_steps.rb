Given /^no (.*) exists with an? (.*) of "([^\"]*)"$/ do |klass_name, attribute, value|
  klass_name.classify.constantize.send(:"find_by_#{attribute}", value).should be_nil
end

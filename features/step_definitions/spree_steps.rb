When /^(?:|I )return to (.+)$/ do |page_name|
  visit path_to(page_name)
end

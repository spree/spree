When /^I attach file "(.*)" to "(.*)"$/ do |file_name, field|
  absolute_path = File.expand_path(Rails.root.join('..', '..', 'features', 'step_definitions', file_name))
  When %Q{I attach the file "#{absolute_path}" to "#{field}"}
end

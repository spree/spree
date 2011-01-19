Given /^2 custom orders$/ do
  Factory(:order, :completed_at => Time.now)
  Factory(:order, :completed_at => 1.year.ago)
end

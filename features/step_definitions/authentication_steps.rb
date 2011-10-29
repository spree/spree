Given /^I am logged out$/ do
  begin
    click_link("Logout")
  rescue Capybara::ElementNotFound
  end
end

Then /^I should be logged in$/ do
  page.should_not have_content("Log In")
  page.should have_content("Logout")
end

Then /^I should be logged out$/ do
  page.should have_content("Log In")
end

Given /^I am signed up as "(.+)\/(.+)"$/ do |email, password|
  Factory(:user, :email => email, :password => password, :password_confirmation => password)
end

Given /^I have an admin account of "(.+)\/(.+)"$/ do |email, password|
  Factory(:admin_user,  :email => email, :password => password, :password_confirmation => password)
end

When /^I sign in as "(.*)\/(.*)"$/ do |email, password|
  When %{I go to the sign in page"}
  And %{I fill in "Email" with "#{email}"}
  And %{I fill in "Password" with "#{password}"}
  And %{I press "Log In"}
end

if defined? CanCan::Ability
  class AbilityDecorator
    include CanCan::Ability

    def initialize(user)
      cannot :manage, Spree::Order
    end
  end
end

Given /^I do not have permission to access orders$/ do
  Spree::Ability.register_ability(AbilityDecorator)
end



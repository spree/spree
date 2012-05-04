require 'spec_helper'

describe "Sign In" do
  before(:each) do
    @user = create(:user, :email => "email@person.com", :password => "secret", :password_confirmation => "secret")
    visit spree.login_path
  end

  it "should ask use to sign in" do
    visit spree.admin_path
    page.should_not have_content("Authorization Failure")
  end

  it "should let a user sign in successfully" do
    fill_in "user_email", :with => @user.email
    fill_in "user_password", :with => @user.password
    click_button "Login"
    page.should have_content("Logged in successfully")
    page.should_not have_content("Login")
    page.should have_content("Logout")
    current_path.should == "/products"
  end

  it "should show validation erros" do
    fill_in "user_email", :with => @user.email
    fill_in "user_password", :with => "wrong_password"
    click_button "Login"
    page.should have_content("Invalid email or password")
    page.should have_content("Login")
  end

  it "should allow a user to access a restricted page after logging in" do
    user = create(:admin_user, :email => "admin@person.com", :password => "password", :password_confirmation => "password")
    visit spree.admin_path
    fill_in "user_email", :with => user.email
    fill_in "user_password", :with => user.password
    click_button "Login"
    page.should have_content("Logged in successfully")
    current_path.should == "/admin"
  end
end

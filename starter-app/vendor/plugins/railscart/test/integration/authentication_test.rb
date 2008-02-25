require "#{File.dirname(__FILE__)}/../test_helper" 
class AuthenticationTest < ActionController::IntegrationTest 
  fixtures :users
  
  def test_successful_login 
    admin = enter_site(:admin) 
    admin.tries_to_go_to_admin 
    admin.logs_in_successfully("admin", "test")
  end 
  
  def test_failing_login
    harry = enter_site(:harry)
    harry.tries_to_go_to_admin
    harry.attempts_login_and_fails("scott", "tiger")
  end
  
  private 
  
  module BrowsingTestDSL 
    include ERB::Util 
    attr_writer :name 
    def tries_to_go_to_admin 
      get "admin/products/new" 
      assert_response :redirect, "Did not redirect after /admin/products/new"
      assert_redirected_to "login", "Did not redirect to the login page"
    end 
    
    def logs_in_successfully(login, password)
      post_login(login, password)
      assert_response :redirect, "Did not redirect after logging in correctly"
      assert_redirected_to "admin/products/new"
    end
    
    def attempts_login_and_fails(login, password)
      post_login(login, password)
      assert_response :success
      assert_template "account/login"
    end
    
    private
    def post_login(login, password)
      post login_path, "login" => login, "password" => password
    end
  end 
  
  def enter_site(name) 
    open_session do |session| 
      session.extend(BrowsingTestDSL) 
      session.name = name 
      yield session if block_given? 
    end 
  end 
end 

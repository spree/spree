require "#{File.dirname(__FILE__)}/../test_helper"

class UserStoriesTest < ActionController::IntegrationTest
  fixtures :products

  def test_truth
    assert true
  end
  
  #test commented out until we have time to refactor it so that it matches current way of doing things

  # User buys a single product
  # TODO - add checkout stuff
  #def test_buying_a_product
  #  session = new_session
  #  session.go_to_store
  #  session.show_product
  #  session.add_to_cart
  #end

  private 
  
  module UserStoriesTestDSL
    attr_writer :name
    attr_reader :user
    
    def go_to_store
      get "/"
      assert_response :success, "unable to access store"
      assert_template "list", "wrong template"
    end
    
    def show_product
      get "/store/show/2"
      assert_response :success, "unable to show product detail"
      assert_template "show", "wrong template"
    end
    
    def add_to_cart
      get "/cart/add/2"
      assert_redirected_to(:controller => 'cart', :action  => 'index')
    end
  end
  
  # Create a session for a user. Block-based.
  #
  #  new_session do |bob|
  #    bob.go_to_login
  #    ...
  #  end
  #
  def new_session
    open_session do |sess|
      sess.extend(UserStoriesTestDSL)
      yield sess if block_given?
    end
  end
  
end

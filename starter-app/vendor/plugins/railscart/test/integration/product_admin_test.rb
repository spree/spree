require "#{File.dirname(__FILE__)}/../test_helper"

class ProductAdminTest < ActionController::IntegrationTest
  fixtures :products, :users
  
  def test_truth
    assert true
  end
  
  #test commented out until we have time to refactor it so that it matches current way of doing things
=begin  
  def test_product_administration
    admin = new_session_as('admin', 'test')
    book = admin.add_product :tags => 'Leather, Hood, Red', :product => {
      :sku => '123ABC',
      :name => "Leather book",
      :description => 'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.',
      :price => 15.00,
      :weight => 2,
      :filename => 'ror_stein.jpg'
    }
    
    admin.list_products
    admin.show_product book
    admin.edit_product(book, :tags => 'Leather, Elvis', :product => {
      :sku => '123ABC',
      :name => 'Leather Book, 2nd Edition',
      :description => 'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.
      Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.
      Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.',
      :price => 16.00,
      :weight => 2
    }, :_method => "put")
    
    #bob = new_session_as('bob', 'test') 
    admin.delete_product book
    
  end
=end  
  private
  
    module ProductTestDSL
      attr_writer :name
      attr_reader :user
      
      def goes_to_login
        get login_url
        assert_response :success
      end
      
      def logs_in_as(login, password)
        @user = users(login.to_sym)
        post "/account/login", "login" => login, "password" => password
        assert_response :redirect
      end
    
      def add_product(parameters)
        post "/admin/products/", parameters
        assert_response :redirect
        follow_redirect!
        assert_response :success
        assert_template "admin/products/show"
        p = Product.find_by_name(parameters[:product][:name])
        assert_equal parameters[:tags].split(',').size, p.tags.size
        return p
      end
      
      def list_products
        get "/admin/products"
        assert_response :success
        assert_template "index"
      end
      
      def show_product(product)
        pid = product.id
        get "/admin/products/#{pid}"
        assert_response :success
        assert_template "admin/products/show"
      end
      
      def edit_product(product, parameters)
        pid = product.id
        get "/admin/products/#{pid};edit"
        assert_response :success
        assert_template "admin/products/edit"
        
        post "/admin/products/#{pid}", parameters
        assert_response :redirect
        follow_redirect!
        assert_response :success
        assert_template "admin/products/show"
        
        product.reload
        assert_equal 2, product.tags.size
      end
      
      def delete_product(product)
        pid = product.id
        post "/admin/products/#{pid}", :_method => "delete"
        assert_response :redirect
        follow_redirect!
        assert_template "admin/products/index"
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
        sess.extend(ProductTestDSL)
        yield sess if block_given?
      end
    end

    # Create a new session and return a user object.
    #
    #   bob = new_session_as('bob', 'atest')
    #   bob.goes_to_newspaper
    #   bob.publishes_article
    #   bob.wins_pulitzer
    #
    
    def new_session_as(login, password)
      new_session do |session|
        session.goes_to_login
        session.logs_in_as(login, password)
        yield session if block_given?
      end
    end
end
module ThoughtBot # :nodoc:
  module Shoulda # :nodoc:
    module Controller
      def self.included(other) # :nodoc:
        other.class_eval do
          extend  ThoughtBot::Shoulda::Controller::ClassMethods
          include ThoughtBot::Shoulda::Controller::InstanceMethods
          ThoughtBot::Shoulda::Controller::ClassMethods::VALID_FORMATS.each do |format|
            include "ThoughtBot::Shoulda::Controller::#{format.to_s.upcase}".constantize
          end
        end
      end
      
      # = Macro test helpers for your controllers
      #
      # By using the macro helpers you can quickly and easily create concise and easy to read test suites.
      # 
      # This code segment:
      #   context "on GET to :show for first record" do
      #     setup do
      #       get :show, :id => 1
      #     end
      #   
      #     should_assign_to :user
      #     should_respond_with :success
      #     should_render_template :show
      #     should_not_set_the_flash
      #
      #     should "do something else really cool" do
      #       assert_equal 1, assigns(:user).id
      #     end
      #   end
      #
      # Would produce 5 tests for the +show+ action
      #
      # Furthermore, the should_be_restful helper will create an entire set of tests which will verify that your
      # controller responds restfully to a variety of requested formats.
      module ClassMethods
        # Formats tested by #should_be_restful.  Defaults to [:html, :xml]
        VALID_FORMATS = Dir.glob(File.join(File.dirname(__FILE__), 'formats', '*.rb')).map { |f| File.basename(f, '.rb') }.map(&:to_sym) # :doc:
        VALID_FORMATS.each {|f| require "shoulda/controller_tests/formats/#{f}.rb"}

        # Actions tested by #should_be_restful
        VALID_ACTIONS = [:index, :show, :new, :edit, :create, :update, :destroy] # :doc:

        # A ResourceOptions object is passed into should_be_restful in order to configure the tests for your controller.
        # 
        # Example:
        #   class UsersControllerTest < Test::Unit::TestCase
        #     load_all_fixtures
        #   
        #     def setup
        #       ...normal setup code...
        #       @user = User.find(:first)
        #     end
        #   
        #     should_be_restful do |resource|
        #       resource.identifier = :id
        #       resource.klass      = User
        #       resource.object     = :user
        #       resource.parent     = []
        #       resource.actions    = [:index, :show, :new, :edit, :update, :create, :destroy]
        #       resource.formats    = [:html, :xml]
        #   
        #       resource.create.params = { :name => "bob", :email => 'bob@bob.com', :age => 13}
        #       resource.update.params = { :name => "sue" }
        #   
        #       resource.create.redirect  = "user_url(@user)"
        #       resource.update.redirect  = "user_url(@user)"
        #       resource.destroy.redirect = "users_url"
        #   
        #       resource.create.flash  = /created/i
        #       resource.update.flash  = /updated/i
        #       resource.destroy.flash = /removed/i    
        #     end
        #   end
        #
        # Whenever possible, the resource attributes will be set to sensible defaults.
        #
        class ResourceOptions
          # Configuration options for the create, update, destroy actions under should_be_restful
          class ActionOptions
            # String evaled to get the target of the redirection.
            # All of the instance variables set by the controller will be available to the 
            # evaled code.
            #
            # Example:
            #   resource.create.redirect  = "user_url(@user.company, @user)"
            #
            # Defaults to a generated url based on the name of the controller, the action, and the resource.parents list.
            attr_accessor :redirect

            # String or Regexp describing a value expected in the flash.  Will match against any flash key.
            #
            # Defaults:
            # destroy:: /removed/
            # create::  /created/
            # update::  /updated/
            attr_accessor :flash
            
            # Hash describing the params that should be sent in with this action.
            attr_accessor :params
          end

          # Configuration options for the denied actions under should_be_restful
          #
          # Example:
          #   context "The public" do
          #     setup do
          #       @request.session[:logged_in] = false
          #     end
          #   
          #     should_be_restful do |resource|
          #       resource.parent = :user
          #   
          #       resource.denied.actions = [:index, :show, :edit, :new, :create, :update, :destroy]
          #       resource.denied.flash = /get outta here/i
          #       resource.denied.redirect = 'new_session_url'
          #     end    
          #   end
          #
          class DeniedOptions
            # String evaled to get the target of the redirection.
            # All of the instance variables set by the controller will be available to the 
            # evaled code.
            #
            # Example:
            #   resource.create.redirect  = "user_url(@user.company, @user)"
            attr_accessor :redirect

            # String or Regexp describing a value expected in the flash.  Will match against any flash key.
            #
            # Example:
            #   resource.create.flash = /created/
            attr_accessor :flash

            # Actions that should be denied (only used by resource.denied).  <i>Note that these actions will
            # only be tested if they are also listed in +resource.actions+</i>
            # The special value of :all will deny all of the REST actions.
            attr_accessor :actions
          end

          # Name of key in params that references the primary key.  
          # Will almost always be :id (default), unless you are using a plugin or have patched rails.
          attr_accessor :identifier
          
          # Name of the ActiveRecord class this resource is responsible for.  Automatically determined from
          # test class if not explicitly set.  UserTest => "User"
          attr_accessor :klass

          # Name of the instantiated ActiveRecord object that should be used by some of the tests.  
          # Defaults to the underscored name of the AR class.  CompanyManager => :company_manager
          attr_accessor :object

          # Name of the parent AR objects.  Can be set as parent= or parents=, and can take either
          # the name of the parent resource (if there's only one), or an array of names (if there's
          # more than one).
          #
          # Example:
          #   # in the routes...
          #   map.resources :companies do
          #     map.resources :people do
          #       map.resources :limbs
          #     end
          #   end
          #
          #   # in the tests...
          #   class PeopleControllerTest < Test::Unit::TestCase
          #     should_be_restful do |resource|
          #       resource.parent = :companies
          #     end
          #   end
          #
          #   class LimbsControllerTest < Test::Unit::TestCase
          #     should_be_restful do |resource|
          #       resource.parents = [:companies, :people]
          #     end
          #   end
          attr_accessor :parent
          alias parents parent
          alias parents= parent=
          
          # Actions that should be tested.  Must be a subset of VALID_ACTIONS (default).
          # Tests for each actionw will only be generated if the action is listed here.
          # The special value of :all will test all of the REST actions.
          #
          # Example (for a read-only controller):
          #   resource.actions = [:show, :index]
          attr_accessor :actions

          # Formats that should be tested.  Must be a subset of VALID_FORMATS (default).
          # Each action will be tested against the formats listed here.  The special value
          # of :all will test all of the supported formats.
          #
          # Example:
          #   resource.actions = [:html, :xml]
          attr_accessor :formats
          
          # ActionOptions object specifying options for the create action.
          attr_accessor :create

          # ActionOptions object specifying options for the update action.
          attr_accessor :update

          # ActionOptions object specifying options for the desrtoy action.
          attr_accessor :destroy

          # DeniedOptions object specifying which actions should return deny a request, and what should happen in that case.
          attr_accessor :denied

          def initialize # :nodoc:
            @create  = ActionOptions.new
            @update  = ActionOptions.new
            @destroy = ActionOptions.new
            @denied  = DeniedOptions.new

            @create.flash  ||= /created/i
            @update.flash  ||= /updated/i
            @destroy.flash ||= /removed/i
            @denied.flash  ||= /denied/i

            @create.params  ||= {}
            @update.params  ||= {}

            @actions = VALID_ACTIONS
            @formats = VALID_FORMATS
            @denied.actions = []
          end

          def normalize!(target) # :nodoc:
            @denied.actions  = VALID_ACTIONS if @denied.actions == :all
            @actions         = VALID_ACTIONS if @actions        == :all
            @formats         = VALID_FORMATS if @formats        == :all
            
            @denied.actions  = @denied.actions.map(&:to_sym)
            @actions         = @actions.map(&:to_sym)
            @formats         = @formats.map(&:to_sym)
            
            ensure_valid_members(@actions,        VALID_ACTIONS, 'actions')
            ensure_valid_members(@denied.actions, VALID_ACTIONS, 'denied.actions')
            ensure_valid_members(@formats,        VALID_FORMATS, 'formats')
            
            @identifier    ||= :id
            @klass         ||= target.name.gsub(/ControllerTest$/, '').singularize.constantize
            @object        ||= @klass.name.tableize.singularize
            @parent        ||= []
            @parent          = [@parent] unless @parent.is_a? Array

            collection_helper = [@parent, @object.to_s.pluralize, 'url'].flatten.join('_')
            collection_args   = @parent.map {|n| "@#{object}.#{n}"}.join(', ')
            @destroy.redirect ||= "#{collection_helper}(#{collection_args})"

            member_helper = [@parent, @object, 'url'].flatten.join('_')
            member_args   = [@parent.map {|n| "@#{object}.#{n}"}, "@#{object}"].flatten.join(', ')
            @create.redirect  ||= "#{member_helper}(#{member_args})"
            @update.redirect  ||= "#{member_helper}(#{member_args})"
            @denied.redirect  ||= "new_session_url"
          end
          
          private
          
          def ensure_valid_members(ary, valid_members, name)  # :nodoc:
            invalid = ary - valid_members
            raise ArgumentError, "Unsupported #{name}: #{invalid.inspect}" unless invalid.empty?
          end
        end

        # :section: should_be_restful
        # Generates a full suite of tests for a restful controller.
        #
        # The following definition will generate tests for the +index+, +show+, +new+, 
        # +edit+, +create+, +update+ and +destroy+ actions, in both +html+ and +xml+ formats:
        #
        #   should_be_restful do |resource|
        #     resource.parent = :user
        #   
        #     resource.create.params = { :title => "first post", :body => 'blah blah blah'}
        #     resource.update.params = { :title => "changed" }
        #   end
        #
        # This generates about 40 tests, all of the format:
        #   "on GET to :show should assign @user."
        #   "on GET to :show should not set the flash."
        #   "on GET to :show should render 'show' template."
        #   "on GET to :show should respond with success."
        #   "on GET to :show as xml should assign @user."
        #   "on GET to :show as xml should have ContentType set to 'application/xml'."
        #   "on GET to :show as xml should respond with success."
        #   "on GET to :show as xml should return <user/> as the root element."
        # The +resource+ parameter passed into the block is a ResourceOptions object, and 
        # is used to configure the tests for the details of your resources.
        #
        def should_be_restful(&blk) # :yields: resource
          resource = ResourceOptions.new
          blk.call(resource)
          resource.normalize!(self)

          resource.formats.each do |format|
            resource.actions.each do |action|
              if self.respond_to? :"make_#{action}_#{format}_tests"
                self.send(:"make_#{action}_#{format}_tests", resource) 
              else
                should "test #{action} #{format}" do
                  flunk "Test for #{action} as #{format} not implemented"
                end
              end
            end
          end
        end

        # :section: Test macros
        
        # Macro that creates a test asserting that the flash contains the given value.
        # val can be a String, a Regex, or nil (indicating that the flash should not be set)
        #
        # Example:
        #
        #   should_set_the_flash_to "Thank you for placing this order."
        #   should_set_the_flash_to /created/i
        #   should_set_the_flash_to nil
        def should_set_the_flash_to(val)
          if val
            should "have #{val.inspect} in the flash" do
              assert_contains flash.values, val, ", Flash: #{flash.inspect}"            
            end
          else
            should "not set the flash" do
              assert_equal({}, flash, "Flash was set to:\n#{flash.inspect}")
            end
          end
        end
    
        # Macro that creates a test asserting that the flash is empty.  Same as
        # @should_set_the_flash_to nil@
        def should_not_set_the_flash
          should_set_the_flash_to nil
        end
        
        # Macro that creates a test asserting that the controller assigned to @name
        #
        # Example:
        #
        #   should_assign_to :user
        def should_assign_to(name)
          should "assign @#{name}" do
            assert assigns(name.to_sym), "The action isn't assigning to @#{name}"
          end
        end

        # Macro that creates a test asserting that the controller did not assign to @name
        #
        # Example:
        #
        #   should_not_assign_to :user
        def should_not_assign_to(name)
          should "not assign to @#{name}" do
            assert !assigns(name.to_sym), "@#{name} was visible"
          end
        end

        # Macro that creates a test asserting that the controller responded with a 'response' status code.
        # Example:
        #
        #   should_respond_with :success
        def should_respond_with(response)
          should "respond with #{response}" do
            assert_response response
          end
        end
    
        # Macro that creates a test asserting that the controller rendered the given template.
        # Example:
        #
        #   should_render_template :new
        def should_render_template(template)
          should "render template #{template.inspect}" do            
            assert_template template.to_s
          end
        end

        # Macro that creates a test asserting that the controller returned a redirect to the given path.
        # The given string is evaled to produce the resulting redirect path.  All of the instance variables
        # set by the controller are available to the evaled string.
        # Example:
        #
        #   should_redirect_to '"/"'
        #   should_redirect_to "users_url(@user)"
        def should_redirect_to(url)
          should "redirect to #{url.inspect}" do
            instantiate_variables_from_assigns do
              assert_redirected_to eval(url, self.send(:binding), __FILE__, __LINE__)
            end
          end
        end
        
        # Macro that creates a test asserting that the rendered view contains a <form> element.
        def should_render_a_form
          should "display a form" do
            assert_select "form", true, "The template doesn't contain a <form> element"            
          end
        end
      end

      module InstanceMethods # :nodoc:
        
        private # :enddoc:
        
        SPECIAL_INSTANCE_VARIABLES = %w{
          _cookies
          _flash
          _headers
          _params
          _request
          _response
          _session
          action_name
          before_filter_chain_aborted
          cookies
          flash
          headers
          ignore_missing_templates
          logger
          params
          request
          request_origin
          response
          session
          template
          template_class
          template_root
          url
          variables_added
        }.map(&:to_s)
        
        def instantiate_variables_from_assigns(*names, &blk)
          old = {}
          names = (@response.template.assigns.keys - SPECIAL_INSTANCE_VARIABLES) if names.empty?
          names.each do |name|
            old[name] = instance_variable_get("@#{name}")
            instance_variable_set("@#{name}", assigns(name.to_sym))
          end
          blk.call
          names.each do |name|
            instance_variable_set("@#{name}", old[name])
          end
        end

        def get_existing_record(res) # :nodoc:
          returning(instance_variable_get("@#{res.object}")) do |record|
            assert(record, "This test requires you to set @#{res.object} in your setup block")    
          end
        end

        def make_parent_params(resource, record = nil, parent_names = nil) # :nodoc:
          parent_names ||= resource.parents.reverse
          return {} if parent_names == [] # Base case
          parent_name = parent_names.shift
          parent = record ? record.send(parent_name) : parent_name.to_s.classify.constantize.find(:first)

          { :"#{parent_name}_id" => parent.to_param }.merge(make_parent_params(resource, parent, parent_names))
        end

      end
    end  
  end
end


module ThoughtBot # :nodoc: 
  module Shoulda # :nodoc: 
    module Controller # :nodoc:
      module XML 
        def self.included(other) #:nodoc:
          other.class_eval do
            extend ThoughtBot::Shoulda::Controller::XML::ClassMethods
          end
        end
  
        module ClassMethods
          # Macro that creates a test asserting that the controller responded with an XML content-type
          # and that the XML contains +<name/>+ as the root element.
          def should_respond_with_xml_for(name = nil)
            should "have ContentType set to 'application/xml'" do
              assert_xml_response
            end
            
            if name
              should "return <#{name}/> as the root element" do
                body = @response.body.first(100).map {|l| "  #{l}"}
                assert_select name.to_s.dasherize, 1, "Body:\n#{body}...\nDoes not have <#{name}/> as the root element."
              end
            end
          end
          alias should_respond_with_xml should_respond_with_xml_for
          
          protected
                    
          def make_show_xml_tests(res) # :nodoc:
            context "on GET to :show as xml" do
              setup do
                request_xml
                record = get_existing_record(res)
                parent_params = make_parent_params(res, record)
                get :show, parent_params.merge({ res.identifier => record.to_param })          
              end

              if res.denied.actions.include?(:show)
                should_not_assign_to res.object
                should_respond_with 401
              else
                should_assign_to res.object          
                should_respond_with :success
                should_respond_with_xml_for res.object
              end
            end
          end

          def make_edit_xml_tests(res) # :nodoc:
            # XML doesn't need an :edit action
          end

          def make_new_xml_tests(res) # :nodoc:
            # XML doesn't need a :new action
          end

          def make_index_xml_tests(res) # :nodoc:
            context "on GET to :index as xml" do
              setup do
                request_xml
                parent_params = make_parent_params(res)
                get(:index, parent_params)          
              end

              if res.denied.actions.include?(:index)
                should_not_assign_to res.object.to_s.pluralize
                should_respond_with 401          
              else
                should_respond_with :success
                should_respond_with_xml_for res.object.to_s.pluralize
                should_assign_to res.object.to_s.pluralize
              end
            end
          end

          def make_destroy_xml_tests(res) # :nodoc:
            context "on DELETE to :destroy as xml" do
              setup do
                request_xml
                @record = get_existing_record(res)
                parent_params = make_parent_params(res, @record)
                delete :destroy, parent_params.merge({ res.identifier => @record.to_param })
              end
        
              if res.denied.actions.include?(:destroy)
                should_respond_with 401
          
                should "not destroy record" do
                  assert @record.reload
                end
              else
                should "destroy record" do
                  assert_raises(::ActiveRecord::RecordNotFound) { @record.reload }
                end
              end
            end
          end

          def make_create_xml_tests(res) # :nodoc:
            context "on POST to :create as xml" do
              setup do
                request_xml
                parent_params = make_parent_params(res)
                @count = res.klass.count
                post :create, parent_params.merge(res.object => res.create.params)
              end
        
              if res.denied.actions.include?(:create)
                should_respond_with 401
                should_not_assign_to res.object
          
                should "not create new record" do
                  assert_equal @count, res.klass.count
                end          
              else
                should_assign_to res.object

                should "not have errors on @#{res.object}" do
                  assert_equal [], assigns(res.object).errors.full_messages, "@#{res.object} has errors:"            
                end
              end      
            end
          end

          def make_update_xml_tests(res) # :nodoc:
            context "on PUT to :update as xml" do
              setup do
                request_xml
                @record = get_existing_record(res)
                parent_params = make_parent_params(res, @record)
                put :update, parent_params.merge(res.identifier => @record.to_param, res.object => res.update.params)
              end

              if res.denied.actions.include?(:update)
                should_not_assign_to res.object
                should_respond_with 401
              else
                should_assign_to res.object

                should "not have errors on @#{res.object}" do
                  assert_equal [], assigns(res.object).errors.full_messages, "@#{res.object} has errors:"
                end
              end
            end
          end
        end

        # Sets the next request's format to 'application/xml'
        def request_xml
          @request.accept = "application/xml"
        end
        
        # Asserts that the controller's response was 'application/xml'
        def assert_xml_response
          assert_equal "application/xml; charset=utf-8", @response.headers['Content-Type'], "Body: #{@response.body.first(100)} ..."
        end
        
      end
    end
  end
end

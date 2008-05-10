module ThoughtBot # :nodoc: 
  module Shoulda # :nodoc: 
    module Controller # :nodoc:
      module HTML # :nodoc: all
        def self.included(other)
          other.class_eval do
            extend ThoughtBot::Shoulda::Controller::HTML::ClassMethods
          end
        end
  
        module ClassMethods 
          def make_show_html_tests(res)
            context "on GET to :show" do
              setup do
                record = get_existing_record(res)
                parent_params = make_parent_params(res, record)
                get :show, parent_params.merge({ res.identifier => record.to_param })          
              end

              if res.denied.actions.include?(:show)
                should_not_assign_to res.object
                should_redirect_to res.denied.redirect
                should_set_the_flash_to res.denied.flash
              else
                should_assign_to res.object          
                should_respond_with :success
                should_render_template :show
                should_not_set_the_flash
              end
            end
          end

          def make_edit_html_tests(res)
            context "on GET to :edit" do
              setup do
                @record = get_existing_record(res)
                parent_params = make_parent_params(res, @record)
                get :edit, parent_params.merge({ res.identifier => @record.to_param })          
              end
        
              if res.denied.actions.include?(:edit)
                should_not_assign_to res.object
                should_redirect_to res.denied.redirect
                should_set_the_flash_to res.denied.flash
              else
                should_assign_to res.object                    
                should_respond_with :success
                should_render_template :edit
                should_not_set_the_flash
                should_render_a_form
                should "set @#{res.object} to requested instance" do
                  assert_equal @record, assigns(res.object)
                end
              end
            end
          end

          def make_index_html_tests(res)
            context "on GET to :index" do
              setup do
                parent_params = make_parent_params(res)
                get(:index, parent_params)          
              end

              if res.denied.actions.include?(:index)
                should_not_assign_to res.object.to_s.pluralize
                should_redirect_to res.denied.redirect
                should_set_the_flash_to res.denied.flash          
              else
                should_respond_with :success
                should_assign_to res.object.to_s.pluralize
                should_render_template :index
                should_not_set_the_flash
              end
            end
          end

          def make_new_html_tests(res)
            context "on GET to :new" do
              setup do
                parent_params = make_parent_params(res)
                get(:new, parent_params)          
              end

              if res.denied.actions.include?(:new)
                should_not_assign_to res.object
                should_redirect_to res.denied.redirect
                should_set_the_flash_to res.denied.flash
              else
                should_respond_with :success
                should_assign_to res.object
                should_not_set_the_flash
                should_render_template :new
                should_render_a_form
              end
            end
          end

          def make_destroy_html_tests(res)
            context "on DELETE to :destroy" do
              setup do
                @record = get_existing_record(res)
                parent_params = make_parent_params(res, @record)
                delete :destroy, parent_params.merge({ res.identifier => @record.to_param })
              end
        
              if res.denied.actions.include?(:destroy)
                should_redirect_to res.denied.redirect
                should_set_the_flash_to res.denied.flash
          
                should "not destroy record" do
                  assert_nothing_raised { assert @record.reload }
                end
              else
                should_set_the_flash_to res.destroy.flash
                if res.destroy.redirect.is_a? Symbol
                  should_respond_with res.destroy.redirect
                else
                  should_redirect_to res.destroy.redirect
                end

                should "destroy record" do
                  assert_raises(::ActiveRecord::RecordNotFound) { @record.reload }
                end
              end
            end
          end

          def make_create_html_tests(res)
            context "on POST to :create with #{res.create.params.inspect}" do
              setup do
                parent_params = make_parent_params(res)
                @count = res.klass.count
                post :create, parent_params.merge(res.object => res.create.params)
              end
        
              if res.denied.actions.include?(:create)
                should_redirect_to res.denied.redirect
                should_set_the_flash_to res.denied.flash
                should_not_assign_to res.object
          
                should "not create new record" do
                  assert_equal @count, res.klass.count
                end          
              else
                should_assign_to res.object
                should_set_the_flash_to res.create.flash
                if res.create.redirect.is_a? Symbol
                  should_respond_with res.create.redirect
                else
                  should_redirect_to res.create.redirect
                end

                should "not have errors on @#{res.object}" do
                  assert_equal [], assigns(res.object).errors.full_messages, "@#{res.object} has errors:"            
                end
              end      
            end
          end

          def make_update_html_tests(res)
            context "on PUT to :update with #{res.create.params.inspect}" do
              setup do
                @record = get_existing_record(res)
                parent_params = make_parent_params(res, @record)
                put :update, parent_params.merge(res.identifier => @record.to_param, res.object => res.update.params)
              end

              if res.denied.actions.include?(:update)
                should_not_assign_to res.object
                should_redirect_to res.denied.redirect
                should_set_the_flash_to res.denied.flash
              else
                should_assign_to res.object
                should_set_the_flash_to(res.update.flash)
                if res.update.redirect.is_a? Symbol
                  should_respond_with res.update.redirect
                else
                  should_redirect_to res.update.redirect
                end
                
                should "not have errors on @#{res.object}" do
                  assert_equal [], assigns(res.object).errors.full_messages, "@#{res.object} has errors:"
                end
              end
            end
          end
        end
      end
    end
  end
end

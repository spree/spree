module Spec
  module Rails
    module Example
      # Helper Specs live in $RAILS_ROOT/spec/helpers/.
      #
      # Helper Specs use Spec::Rails::Example::HelperExampleGroup, which allows you to
      # include your Helper directly in the context and write specs directly
      # against its methods.
      #
      # HelperExampleGroup also includes the standard lot of ActionView::Helpers in case your
      # helpers rely on any of those.
      #
      # == Example
      #
      #   class ThingHelper
      #     def number_of_things
      #       Thing.count
      #     end
      #   end
      #
      #   describe "ThingHelper example_group" do
      #     include ThingHelper
      #     it "should tell you the number of things" do
      #       Thing.should_receive(:count).and_return(37)
      #       number_of_things.should == 37
      #     end
      #   end
      class HelperExampleGroup < FunctionalExampleGroup
        class HelperObject < ActionView::Base
          def protect_against_forgery?
            false
          end
          
          def session=(session)
            @session = session
          end
          
          def request=(request)
            @request = request
          end
          
          def flash=(flash)
            @flash = flash
          end
          
          def params=(params)
            @params = params
          end
          
          def controller=(controller)
            @controller = controller
          end
          
          private
            attr_reader :session, :request, :flash, :params, :controller
        end
        
        class << self
          # The helper name....
          def helper_name(name=nil)
            @helper_being_described = "#{name}_helper".camelize.constantize
            send :include, @helper_being_described
          end
          
          def helper
            @helper_object ||= returning HelperObject.new do |helper_object|
              if @helper_being_described.nil?
                if described_type.class == Module
                  helper_object.extend described_type
                end
              else
                helper_object.extend @helper_being_described
              end
            end
          end
        end
        
        # Returns an instance of ActionView::Base with the helper being spec'd
        # included.
        #
        # == Example
        #
        #   describe PersonHelper do
        #     it "should write a link to person with the name" do
        #       assigns[:person] = mock_model(Person, :full_name => "Full Name", :id => 37, :new_record? => false)
        #       helper.link_to_person.should == %{<a href="/people/37">Full Name</a>}
        #     end
        #   end
        #
        #   module PersonHelper
        #     def link_to_person
        #       link_to person.full_name, url_for(person)
        #     end
        #   end
        #
        def helper
          self.class.helper
        end

        # Reverse the load order so that custom helpers which are defined last
        # are also loaded last.
        ActionView::Base.included_modules.reverse.each do |mod|
          include mod if mod.parents.include?(ActionView::Helpers)
        end

        before(:all) do
          @controller_class_name = 'Spec::Rails::Example::HelperExampleGroupController'
        end

        before(:each) do
          @controller.request = @request
          @controller.url = ActionController::UrlRewriter.new @request, {} # url_for

          @flash = ActionController::Flash::FlashHash.new
          session['flash'] = @flash

          ActionView::Helpers::AssetTagHelper::reset_javascript_include_default
          
          helper.session = session
          helper.request = @request
          helper.flash = flash
          helper.params = params
          helper.controller = @controller
        end

        def flash
          @flash
        end

        def eval_erb(text)
          erb_args = [text]
          if helper.respond_to?(:output_buffer)
            erb_args += [nil, nil, '@output_buffer']
          end
          
          helper.instance_eval do
            ERB.new(*erb_args).result(binding)
          end
        end

        # TODO: BT - Helper Examples should proxy method_missing to a Rails View instance.
        # When that is done, remove this method
        def protect_against_forgery?
          false
        end

        Spec::Example::ExampleGroupFactory.register(:helper, self)

        protected
        def _assigns_hash_proxy
          @_assigns_hash_proxy ||= AssignsHashProxy.new helper
        end

      end

      class HelperExampleGroupController < ApplicationController #:nodoc:
        attr_accessor :request, :url

        # Re-raise errors
        def rescue_action(e); raise e; end
      end
    end
  end
end

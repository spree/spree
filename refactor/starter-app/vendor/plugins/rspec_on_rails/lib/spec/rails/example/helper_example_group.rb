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
        class << self
          # The helper name....
          def helper_name(name=nil)
            send :include, "#{name}_helper".camelize.constantize
          end
        end

        # Reverse the load order so that custom helpers which
        # are defined last are also loaded last.
        ActionView::Base.included_modules.reverse.each do |mod|
          include mod if mod.parents.include?(ActionView::Helpers)
        end

        before(:all) do
          @controller_class_name = 'Spec::Rails::Example::HelperBehaviourController'
        end

        before(:each) do
          @controller.request = @request
          @controller.url = ActionController::UrlRewriter.new @request, {} # url_for

          @flash = ActionController::Flash::FlashHash.new
          session['flash'] = @flash

          ActionView::Helpers::AssetTagHelper::reset_javascript_include_default
        end

        def flash
          @flash
        end

        def eval_erb(text)
          ERB.new(text).result(binding)
        end


        # TODO: BT - Helper Examples should proxy method_missing to a Rails View instance.
        # When that is done, remove this method
        def protect_against_forgery?
          false
        end

        Spec::Example::ExampleGroupFactory.register(:helper, self)
      end

      class HelperBehaviourController < ApplicationController #:nodoc:
        attr_accessor :request, :url

        # Re-raise errors
        def rescue_action(e); raise e; end
      end
    end
  end
end

module Spec
  module Rails
    module Example
      class FunctionalExampleGroup < RailsExampleGroup
        include ActionController::TestProcess
        include ActionController::Assertions

        attr_reader :request, :response
        before(:each) do
          @controller_class = Object.path2class @controller_class_name
          raise "Can't determine controller class for #{@controller_class_name}" if @controller_class.nil?

          @controller = @controller_class.new
          @request = ActionController::TestRequest.new
          @response = ActionController::TestResponse.new
          @response.session = @request.session
        end

        def params
          request.parameters
        end

        def flash
          response.flash
        end

        def session
          response.session
        end

        # :call-seq:
        #   assigns()
        #
        # Hash of instance variables to values that are made available to
        # views. == Examples
        #
        #   #in thing_controller.rb
        #   def new
        #     @thing = Thing.new
        #   end
        #
        #   #in thing_controller_spec
        #   get 'new'
        #   assigns[:registration].should == Thing.new
        #--
        # NOTE - Even though docs only use assigns[:key] format, this supports
        # assigns(:key) in order to avoid breaking old specs.
        #++
        def assigns(key = nil)
          if key.nil?
            _assigns_hash_proxy
          else
            _assigns_hash_proxy[key]
          end
        end
      end
    end
  end
end

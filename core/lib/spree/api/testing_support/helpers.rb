module Spree
  module Api
    module TestingSupport
      module Helpers
        def json_response
          JSON.parse(response.body)
        end

        def assert_unauthorized!
          json_response.should == { "error" => "You are not authorized to perform that action." }
          response.status.should == 401
        end

        def stub_authentication!
          controller.stub :check_for_api_key
          Spree::LegacyUser.stub :find_by_spree_api_key => current_api_user
        end

        # This method can be overriden (with a let block) inside a context
        # For instance, if you wanted to have an admin user instead.
        def current_api_user
          @current_api_user ||= stub_model(Spree::LegacyUser, :email => "spree@example.com")
        end

        def image(filename)
          File.open(Spree::Core::Engine.root + "spec/fixtures" + filename)
        end

        def upload_image(filename)
          fixture_file_upload(image(filename).path)
        end
      end
    end
  end
end

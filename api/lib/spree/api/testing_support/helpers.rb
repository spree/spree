module Spree
  module Api
    module TestingSupport
      module Helpers
        def json_response
          case body = JSON.parse(response.body)
          when Hash
            body.with_indifferent_access
          when Array
            body
          end
        end

        def assert_not_found!
          expect(json_response).to eq('error' => 'The resource you were looking for could not be found.')
          expect(response.status).to eq 404
        end

        def assert_unauthorized!
          expect(json_response).to eq('error' => 'You are not authorized to perform that action.')
          expect(response.status).to eq 401
        end

        def stub_authentication!
          allow(Spree.user_class).to receive(:find_by).with(hash_including(:spree_api_key)) { current_api_user }
        end

        # This method can be overriden (with a let block) inside a context
        # For instance, if you wanted to have an admin user instead.
        def current_api_user
          @current_api_user ||= stub_model(Spree.user_class, email: 'spree@example.com')
        end

        def image(filename)
          File.open(Spree::Api::Engine.root + 'spec/fixtures' + filename)
        end

        def upload_image(filename)
          fixture_file_upload(image(filename).path, 'image/jpg')
        end
      end
    end
  end
end

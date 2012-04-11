module Spree
  module Api
    module TestingSupport
      module Setup
        def sign_in_as_admin!
          let!(:current_api_user) do
            user = stub_model(Spree::User)
            user.should_receive(:has_role?).any_number_of_times.with("admin").and_return(true)
            user
          end
        end

        # Default kaminari's pagination to a certain range
        # Means that you don't need to create 25 objects to test pagination
        def default_per_page(count)
          before do
            @current_default_per_page = Kaminari.config.default_per_page
            Kaminari.config.default_per_page = 1
          end

          after do
            Kaminari.config.default_per_page = @current_default_per_page
          end
        end
      end
    end
  end
end

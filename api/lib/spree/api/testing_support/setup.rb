module Spree
  module Api
    module TestingSupport
      module Setup
        def sign_in_as_admin!
          let!(:current_api_user) do
            user = stub_model(Spree::LegacyUser)
            user.should_receive(:has_spree_role?).any_number_of_times.with("admin").and_return(true)
            user
          end
        end
      end
    end
  end
end

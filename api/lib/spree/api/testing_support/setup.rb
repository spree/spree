module Spree
  module Api
    module TestingSupport
      module Setup
        def sign_in_as_admin!
          let!(:current_api_user) do
            user = stub_model(Spree.user_class)
            allow(user).to receive_message_chain(:spree_roles, :pluck).and_return(["admin"])
            allow(user).to receive(:has_spree_role?).with("admin").and_return(true)
            user
          end
        end
      end
    end
  end
end

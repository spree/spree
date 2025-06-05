module Spree
  module Storefront
    module TestingSupport
      module Auth
        def sign_in(user)
          visit '/user/sign_in'
          fill_in 'Email', with: user.email
          fill_in 'Password', with: user.password
          click_on 'Login'
          expect(page).to have_content('Signed in successfully')
        end

        def mock_sign_in(user)
          allow_any_instance_of(Spree::StoreController).to receive(:try_spree_current_user).and_return(user)
        end
      end
    end
  end
end

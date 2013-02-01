module Spree
  module TestingSupport
    module AuthorizationHelpers
      module Controller
        def stub_authorization!
          before do
            controller.should_receive(:authorize!).and_return(true)
          end
        end
      end

      module Request
        class SuperAbility
          include CanCan::Ability

          def initialize(user)
            # allow anyone to perform anything on anything
            can :manage, :all
          end
        end

        def stub_authorization!
          before(:all) do
            ability = Spree::TestingSupport::AuthorizationHelpers::Request::SuperAbility
            Spree::Ability.register_ability(ability)
          end
        end
      end
    end
  end
end

RSpec.configure do |config|
  config.extend Spree::TestingSupport::AuthorizationHelpers::Controller, :type => :controller
  config.extend Spree::TestingSupport::AuthorizationHelpers::Request, :type => :request
end

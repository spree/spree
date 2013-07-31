module Spree
  module TestingSupport
    module AuthorizationHelpers
      module Controller
        def stub_authorization!
          before do
            controller.stub :authorize! => true
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
          after(:all) do
            ability = Spree::TestingSupport::AuthorizationHelpers::Request::SuperAbility
            Spree::Ability.remove_ability(ability)
          end
          before(:all) do
            ability = Spree::TestingSupport::AuthorizationHelpers::Request::SuperAbility
            Spree::Ability.register_ability(ability)
          end
        end

        def custom_authorization!(&block)
          ability = Class.new do
            include CanCan::Ability
            define_method(:initialize, block)
          end
          after(:all) do
            Spree::Ability.remove_ability(ability)
          end
          before(:all) do
            Spree::Ability.register_ability(ability)
          end
        end
      end
    end
  end
end

RSpec.configure do |config|
  config.extend Spree::TestingSupport::AuthorizationHelpers::Controller, :type => :controller
  config.extend Spree::TestingSupport::AuthorizationHelpers::Request, :type => :feature
end

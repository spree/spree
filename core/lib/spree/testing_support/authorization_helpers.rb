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
        class BarAbility
          include CanCan::Ability

          def initialize(user)
            # allow dispatch to :admin, :index, and :edit on Spree::Order
            can [:admin, :edit, :index, :read], Spree::Order
            # allow dispatch to :index, :show, :create and :update shipments on the admin
            can [:admin, :manage, :read, :ship], Spree::Shipment
          end
        end

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

        def stub_bar_authorization!
          after(:all) do
            ability = Spree::TestingSupport::AuthorizationHelpers::Request::BarAbility
            Spree::Ability.remove_ability(ability)
          end
          before(:all) do
            ability = Spree::TestingSupport::AuthorizationHelpers::Request::BarAbility
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

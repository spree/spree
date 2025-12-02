module Spree
  module TestingSupport
    module AuthorizationHelpers
      module CustomAbility
        def build_ability(&block)
          block ||= proc { |_u| can :manage, :all }
          Class.new do
            include CanCan::Ability
            define_method(:initialize, block)
          end
        end
      end

      module Controller
        include CustomAbility

        def stub_authorization!(&block)
          let(:admin_user) { FactoryBot.create(:admin_user) }

          before do
            if defined?(Spree::Admin::BaseController)
              allow_any_instance_of(Spree::Admin::BaseController).to receive(:try_spree_current_user).and_return(admin_user)
            end
          end
        end
      end

      module Request
        include CustomAbility

        def stub_authorization!
          ability = build_ability
          ability_class = Spree.ability_class

          after(:all) do
            ability_class.remove_ability(ability)
          end

          before(:all) do
            ability_class.register_ability(ability)
          end

          let(:admin_user) { FactoryBot.create(:admin_user) }

          before do
            if defined?(Spree::Admin::BaseController)
              allow_any_instance_of(Spree::Admin::BaseController).to receive(:try_spree_current_user).and_return(admin_user)
            end
          end
        end

        def custom_authorization!(&block)
          ability = build_ability(&block)
          ability_class = Spree.ability_class

          after(:all) do
            ability_class.remove_ability(ability)
          end
          before(:all) do
            ability_class.register_ability(ability)
          end
        end
      end
    end
  end
end

RSpec.configure do |config|
  config.extend Spree::TestingSupport::AuthorizationHelpers::Controller, type: :controller
  config.extend Spree::TestingSupport::AuthorizationHelpers::Request, type: :feature
  config.extend Spree::TestingSupport::AuthorizationHelpers::Request, type: :request
end

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
          ability_class = build_ability(&block)

          let(:user) { Spree.admin_user_class.new(email: FFaker::Internet.email) }

          before do
            allow(controller).to receive(:current_ability).and_return(ability_class.new(nil))

            if defined?(Spree::Admin::BaseController)
              allow_any_instance_of(Spree::Admin::BaseController).to receive(:try_spree_current_user).and_return(user)
            end
          end
        end
      end

      module Request
        include CustomAbility

        def stub_authorization!
          ability = build_ability
          ability_class = Spree::Dependencies.ability_class.constantize

          after(:all) do
            ability_class.remove_ability(ability)
          end

          before(:all) do
            ability_class.register_ability(ability)
          end

          let(:user) { Spree.admin_user_class.new(email: FFaker::Internet.email) }

          before do
            allow(Spree.admin_user_class).to receive(:find_by).and_return(user)
            if defined?(Spree::Admin::BaseController)
              allow_any_instance_of(Spree::Admin::BaseController).to receive(:try_spree_current_user).and_return(user)
            end
          end
        end

        def custom_authorization!(&block)
          ability = build_ability(&block)
          ability_class = Spree::Dependencies.ability_class.constantize

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
end

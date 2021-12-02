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
          before do
            allow(controller).to receive(:current_ability).and_return(ability_class.new(nil))
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

          let(:admin_app) { Spree::OauthApplication.create!(name: 'Admin Panel', scopes: 'admin') }
          let(:admin_token) { Spree::OauthAccessToken.create!(application: admin_app, scopes: 'admin').token }

          before do
            allow(Spree.user_class).to receive(:find_by).and_return(Spree.user_class.new)
            if defined?(Spree::Admin)
              allow_any_instance_of(Spree::Admin::BaseController).to receive(:admin_oauth_application).and_return(admin_app)
              allow_any_instance_of(Spree::Admin::BaseController).to receive(:admin_oauth_token).and_return(admin_token)
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

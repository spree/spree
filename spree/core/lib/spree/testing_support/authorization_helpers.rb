module Spree
  module TestingSupport
    module AuthorizationHelpers
      module CustomAbility
        def build_permission_set(&block)
          block ||= proc { |_u| can :manage, :all }
          Class.new(Spree::PermissionSets::Base) do
            define_method(:activate!) do
              instance_exec(user, &block)
            end
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
          permission_set = build_permission_set

          before(:all) do
            Spree.permissions.assign(:admin, permission_set)
          end

          after(:all) do
            Spree.permissions.unassign(:admin, permission_set)
          end

          let(:admin_user) { FactoryBot.create(:admin_user) }

          before do
            if defined?(Spree::Admin::BaseController)
              allow_any_instance_of(Spree::Admin::BaseController).to receive(:try_spree_current_user).and_return(admin_user)
            end
          end
        end

        def custom_authorization!(&block)
          permission_set = build_permission_set(&block)

          before(:all) do
            Spree.permissions.assign(:admin, permission_set)
          end

          after(:all) do
            Spree.permissions.unassign(:admin, permission_set)
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

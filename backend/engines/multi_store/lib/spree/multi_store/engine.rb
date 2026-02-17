module Spree
  module MultiStore
    class Engine < ::Rails::Engine
      isolate_namespace Spree
      engine_name 'spree_multi_store'

      # Rails 7.1 introduced a new feature that raises an error if a callback action is missing.
      # We need to disable it as we use a lot of concerns that add callback actions.
      initializer 'spree.multi_store.disable_raise_on_missing_callback_actions' do |app|
        app.config.action_controller.raise_on_missing_callback_actions = false
      end
    end
  end
end

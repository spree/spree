require 'rails/engine'

module Spree
  module Assistant
    class Engine < Rails::Engine
      isolate_namespace Spree
      engine_name 'spree_assistant'

      # `open_ai.rb` defines OpenAI, not OpenAi — the vendor spells it that way
      # and the class names read badly otherwise.
      initializer 'spree_assistant.inflections' do
        Rails.autoloaders.each do |autoloader|
          autoloader.inflector.inflect('open_ai' => 'OpenAI')
        end
      end

      # Seeded before host initializer files run, so a host app or extension can
      # register its own providers from an initializer — the same ordering the
      # tax and delivery-rate registries use. Tools are core's
      # (`Spree.admin_agent_tools`), shared with the MCP server.
      initializer 'spree_assistant.register.registries', before: :load_config_initializers do |app|
        app.config.spree_assistant = Spree::Assistant::Environment.new([])
      end

      # Appended rather than assigned, so anything registered above survives.
      config.after_initialize do
        Spree::Assistant.providers.push(
          Spree::AssistantProvider::Anthropic,
          Spree::AssistantProvider::OpenAI,
          Spree::AssistantProvider::Gemini
        )

        Spree.integrations.push(
          'Spree::Integrations::Anthropic',
          'Spree::Integrations::OpenAI',
          'Spree::Integrations::Gemini'
        )

        # The assistant is its own permission resource: holding it is what lets
        # an admin open a conversation at all, separate from what the tools
        # inside it may touch.
        Spree.permissions.register_scope(
          :assistant,
          group: :settings,
          resources: -> { [Spree::AssistantChat] }
        )
      end
    end
  end
end

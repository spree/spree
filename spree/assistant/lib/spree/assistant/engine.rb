require 'rails/engine'

module Spree
  module Assistant
    class Engine < Rails::Engine
      isolate_namespace Spree
      engine_name 'spree_assistant'

      config.paths.add 'app/tools', eager_load: true

      # `open_ai.rb` defines OpenAI, not OpenAi — the vendor spells it that way
      # and the class names read badly otherwise.
      initializer 'spree_assistant.inflections' do
        Rails.autoloaders.each do |autoloader|
          autoloader.inflector.inflect('open_ai' => 'OpenAI')
        end
      end

      # Seeded before host initializer files run, so a host app or extension can
      # register its own tools and providers from an initializer — the same
      # ordering the tax and delivery-rate registries use.
      initializer 'spree_assistant.register.registries', before: :load_config_initializers do |app|
        app.config.spree_assistant = Spree::Assistant::Environment.new(
          Spree::Assistant::Registry.new([]),
          []
        )
      end

      # Concatenated rather than assigned, so anything registered above survives.
      config.after_initialize do
        Spree::Assistant.providers.concat(
          [
            Spree::AssistantProvider::Anthropic,
            Spree::AssistantProvider::OpenAI,
            Spree::AssistantProvider::Gemini
          ]
        )

        # Names, not classes: the registry resolves them per use, so editing a
        # tool's description or params in development takes effect on the next
        # request instead of the next boot.
        %w[
          Spree::Assistant::Tools::DescribeResource
          Spree::Assistant::Tools::SearchResources
          Spree::Assistant::Tools::GetResource
          Spree::Assistant::Tools::UpdateProductStatus
        ].each { |tool_class| Spree::Assistant.tools << tool_class }

        Spree.integrations.concat(
          %w[
            Spree::Integrations::Anthropic
            Spree::Integrations::OpenAI
            Spree::Integrations::Gemini
          ]
        )

        # The assistant is its own permission resource: holding it is what lets
        # an admin open a conversation at all, separate from what the tools
        # inside it may touch.
        Spree.permissions.register_resource(
          :assistant,
          group: :settings,
          subjects: -> { [Spree::AssistantChat] }
        )
      end
    end
  end
end

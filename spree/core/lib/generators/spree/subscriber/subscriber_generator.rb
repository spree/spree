# frozen_string_literal: true

module Spree
  # spree:subscriber — scaffold an event subscriber and register it.
  #
  #   bin/rails g spree:subscriber OmsOrderSync order.completed order.canceled
  #   bin/rails g spree:subscriber MyApp::BrandSync brand.created brand.updated
  #   bin/rails g spree:subscriber CriticalSync order.completed --sync
  #
  # Subscribers are not auto-discovered — they must be appended to the
  # Spree.subscribers array. Forgetting that step produces a silent no-op,
  # so this generator also maintains the registration in
  # config/initializers/spree.rb with an idempotent line per subscriber.
  class SubscriberGenerator < Rails::Generators::NamedBase
    desc 'Creates a Spree event subscriber and registers it in an initializer'

    # Every Spree app ships config/initializers/spree.rb (created by
    # spree:install) — registrations go there rather than into a second
    # initializer file.
    INITIALIZER_PATH = 'config/initializers/spree.rb'
    REGISTRATION_ANCHOR = "Rails.application.config.after_initialize do\n"

    argument :events, type: :array, default: [], banner: 'event.name event.name'

    class_option :sync,
                 type: :boolean,
                 default: false,
                 desc: 'Run the subscriber synchronously (async: false) instead of via ActiveJob'

    class_option :skip_spec,
                 type: :boolean,
                 default: false,
                 desc: "Don't generate a spec file"

    def self.source_paths
      [File.expand_path('templates', __dir__), *superclass.source_paths]
    end

    def create_subscriber_file
      template 'subscriber.rb.tt', File.join('app/subscribers', class_path, "#{subscriber_file_name}.rb")
    end

    def register_subscriber
      if File.exist?(destination_path(INITIALIZER_PATH))
        content = File.read(destination_path(INITIALIZER_PATH))
        if content.include?(registration_line.strip)
          say_status :identical, "#{INITIALIZER_PATH} (#{subscriber_class_name} already registered)", :blue
        elsif content.include?(REGISTRATION_ANCHOR)
          inject_into_file INITIALIZER_PATH, registration_line, after: REGISTRATION_ANCHOR
        else
          append_to_file INITIALIZER_PATH, registration_block
        end
      else
        create_file INITIALIZER_PATH, registration_block.lstrip
      end
    end

    def create_spec_file
      return if options[:skip_spec]

      template 'subscriber_spec.rb.tt', File.join('spec/subscribers', class_path, "#{subscriber_file_name}_spec.rb")
    end

    def warn_about_missing_events
      return if events.any?

      say_status :note, "no events given — edit `subscribes_to` in the generated subscriber (e.g. 'order.completed')", :yellow
    end

    private

    # "OmsOrderSync" and "OmsOrderSyncSubscriber" both produce
    # OmsOrderSyncSubscriber / oms_order_sync_subscriber.
    def bare_subscriber_name
      base = class_name.demodulize.sub(/Subscriber\z/, '')
      "#{base}Subscriber"
    end

    def subscriber_file_name
      bare_subscriber_name.underscore
    end

    def subscriber_class_name
      (class_path.map { |part| part.camelize } + [bare_subscriber_name]).join('::')
    end

    def namespace_modules
      class_path.map(&:camelize)
    end

    def subscribes_to_arguments
      listed = events.any? ? events.map { |e| "'#{e}'" } : ["'TODO.replace_with_event_name'"]
      listed << 'async: false' if options[:sync]
      listed.join(', ')
    end

    def registration_line
      "  Spree.subscribers << #{subscriber_class_name}\n"
    end

    def registration_block
      <<~RUBY

        # Event subscribers must be registered explicitly — Spree does not
        # auto-discover classes in app/subscribers/.
        Rails.application.config.after_initialize do
        #{registration_line.chomp}
        end
      RUBY
    end

    def destination_path(relative)
      File.join(destination_root, relative)
    end
  end
end

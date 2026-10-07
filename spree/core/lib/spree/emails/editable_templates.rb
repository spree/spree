module Spree
  module Emails
    # The email templates merchants may edit in the dashboard: the emails
    # customers receive, plus the layout and shared partials those emails are
    # built from. Staff, store-owner and seller emails are never registered, so
    # they always render from files. `spree_emails` registers its own; an
    # extension adding a customer email registers it the same way.
    #
    # @example
    #   Spree.editable_email_templates.register(
    #     'spree/loyalty_mailer/points_earned_email',
    #     kind: :email, sample: 'MyApp::EmailSamples::PointsEarned'
    #   )
    class EditableTemplates
      include Enumerable

      KINDS = %i[email layout partial].freeze

      # One editable template.
      class Definition
        attr_reader :key, :kind, :sample

        # @param key [String] the template's view path, e.g. "spree/order_mailer/confirm_email"
        # @param kind [Symbol] :email, :layout or :partial
        # @param sample [String, nil] class building sample variables for an email (see Spree::Emails::Samples::Base)
        def initialize(key:, kind:, sample: nil)
          raise ArgumentError, "Unknown email template kind: #{kind.inspect}" unless KINDS.include?(kind)

          @key = key
          @kind = kind
          @sample = sample
        end

        def email?
          kind == :email
        end

        # @return [Class, nil]
        def sample_class
          sample&.constantize
        end
      end

      def initialize
        @definitions = {}
      end

      # @param key [String]
      # @param kind [Symbol]
      # @param sample [String, nil]
      # @return [Spree::Emails::EditableTemplates::Definition]
      def register(key, kind: :email, sample: nil)
        @definitions[key] = Definition.new(key: key, kind: kind, sample: sample)
      end

      # @param key [String]
      def delete(key)
        @definitions.delete(key)
      end

      # @param key [String]
      # @return [Spree::Emails::EditableTemplates::Definition, nil]
      def [](key)
        @definitions[key]
      end

      # @param key [String]
      def include?(key)
        @definitions.key?(key)
      end

      def each(&block)
        @definitions.each_value(&block)
      end

      # @return [Array<Spree::Emails::EditableTemplates::Definition>] the editable emails, without layout and partials
      def emails
        select(&:email?)
      end
    end
  end
end

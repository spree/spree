module Spree
  module Emails
    # Renders an email template into its subject, HTML and plain-text parts.
    #
    # Liquid fills in the data first, into the template and then the layout
    # wrapping it; MJML then compiles the result into email-safe HTML. Every
    # output is HTML-escaped unless a template marks it `| raw`, and a runaway
    # template fails its one email rather than stalling the job queue.
    class Renderer
      LAYOUT = 'layouts/spree/base_mailer'.freeze

      RESOURCE_LIMITS = {
        render_length_limit: 2_000_000,
        render_score_limit: 200_000,
        assign_score_limit: 50_000
      }.freeze

      class << self
        # The Liquid environment every email renders in: strict parsing and
        # Spree's filters, isolated from any other Liquid the host app runs.
        #
        # @return [Liquid::Environment]
        def environment
          @environment ||= Liquid::Environment.build(error_mode: :strict) do |environment|
            environment.register_filter(Spree::Emails::Filters)
          end
        end
      end

      # @param resolver [Spree::Emails::TemplateResolver]
      # @param store [Spree::Store]
      # @param currency [String, nil] what `money` formats in, defaults to the store's
      def initialize(resolver:, store:, currency: nil)
        @resolver = resolver
        @store = store
        @currency = currency.presence || store.default_currency
      end

      # @param template [Spree::Emails::Template] a Liquid template
      # @param assigns [Hash] the template's variables
      # @return [Spree::Emails::RenderedEmail]
      def render(template, assigns = {})
        assigns = base_assigns.merge(assigns.deep_stringify_keys)
        subject = render_subject(template, assigns)
        body = render_liquid(template.body, assigns)
        layout = @resolver.find_liquid(LAYOUT) || raise(ArgumentError, "Missing email layout #{LAYOUT}.liquid")
        mjml = render_liquid(layout.body, assigns.merge('subject' => subject, 'content_for_layout' => body.html_safe))
        html = MRML.to_html(mjml)

        Spree::Emails::RenderedEmail.new(subject: subject, html: html, text: render_text(template, assigns, html))
      end

      # The subject is plain text for a mail header, so it is not HTML-escaped.
      #
      # @param template [Spree::Emails::Template]
      # @param assigns [Hash]
      # @return [String]
      def render_subject(template, assigns = {})
        assigns = base_assigns.merge(assigns.deep_stringify_keys)

        render_liquid(template.subject.to_s, assigns, escape: false).squish
      end

      private

      def render_text(template, assigns, html)
        text_template = @resolver.find_text(template.key)
        return Spree::Emails::TextConverter.call(html) unless text_template

        render_liquid(text_template.body, assigns, escape: false)
      end

      def render_liquid(source, assigns, escape: true)
        context = Spree::Emails::LiquidContext.build(
          environment: self.class.environment,
          environments: [assigns],
          registers: { store: @store, currency: @currency, file_system: Spree::Emails::FileSystem.new(@resolver) },
          resource_limits: Liquid::ResourceLimits.new(RESOURCE_LIMITS),
          rethrow_errors: true
        )
        context.escape_output = escape
        context.strict_variables = strict?
        context.strict_filters = true

        Liquid::Template.parse(source, environment: self.class.environment).render!(context)
      end

      def base_assigns
        @base_assigns ||= {
          'store' => JSON.parse(Spree::Emails::StoreSerializer.new(@store).serialize),
          'locale' => I18n.locale.to_s
        }
      end

      # An unknown variable raises in development and test, so a typo fails
      # a spec rather than rendering blank; production renders it empty.
      def strict?
        Rails.env.local?
      end
    end
  end
end

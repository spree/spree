module Spree
  # An anonymised description of this installation for bug reports: versions,
  # stack, store setup by prefixed ID, providers, changed settings and recent
  # Spree errors. The rake task, the Admin API and the CLI all render this one
  # report, so what a maintainer reads is the same wherever it came from.
  #
  #   report = Spree::Diagnostics.report(store: Spree::Current.store)
  #   puts report.to_markdown
  class Diagnostics
    ISSUE_URL = 'https://github.com/spree/spree/issues/new?template=bug_report.yml'.freeze
    # GitHub refuses very long URLs; past this the issue form opens empty and
    # the report is pasted by hand.
    MAX_ISSUE_URL_LENGTH = 6000

    # A built report. Never persisted.
    class Report
      attr_reader :generated_at, :sections, :errors

      def initialize(generated_at:, sections:, errors:)
        @generated_at = generated_at
        @sections = sections
        @errors = errors
      end

      # @return [String] Spree version, for the report's headline
      def spree_version
        Spree.version
      end

      # @return [Hash]
      def to_h
        { generated_at: generated_at.iso8601, spree_version: spree_version, sections: sections, errors: errors,
          markdown: to_markdown, issue_url: issue_url, issue_prefilled: issue_prefilled? }
      end

      # A new GitHub issue with the report filled in, or the empty form when
      # the report is too long for a URL.
      #
      # @return [String]
      def issue_url
        @issue_url ||= begin
          prefilled = "#{ISSUE_URL}&environment=#{ERB::Util.url_encode(to_markdown)}"
          prefilled.length <= MAX_ISSUE_URL_LENGTH ? prefilled : ISSUE_URL
        end
      end

      # @return [Boolean]
      def issue_prefilled?
        issue_url != ISSUE_URL
      end

      # GitHub-flavoured Markdown, folded into a <details> block so it doesn't
      # take over the issue it is pasted into.
      #
      # @return [String]
      def to_markdown
        @to_markdown ||= render_markdown
      end

      private

      def render_markdown
        lines = ['<details>', "<summary>Spree #{spree_version} diagnostics (#{generated_at.iso8601})</summary>", '']

        sections.each do |section|
          next if section[:rows].empty?

          lines.push("**#{section[:title]}**", '', '| | |', '| --- | --- |')
          section[:rows].each { |row| lines << "| #{escape(row[:label])} | #{escape(row[:value])} |" }
          lines << ''
        end

        if errors
          lines.push('**Recent errors**', '')
          lines << 'None recorded.' if errors.empty?
          errors.each do |error|
            lines << "- `#{error[:error_class]}` × #{error[:count]}, last #{error[:last_seen_at]}#{" (#{error[:source]})" if error[:source]}"
            error[:frames].each { |frame| lines << "  - `#{frame}`" }
          end
          lines << ''
        end

        lines << '</details>'
        lines.join("\n")
      end

      def escape(value)
        value.to_s.gsub('|', '\|').gsub("\n", ' ')
      end
    end

    class << self
      # @param store [Spree::Store]
      # @param extra_sections [Array<Hash>] what only the caller can see, as
      #   `{ title:, rows: { label => value } }` — the CLI's tooling, the
      #   dashboard's browser
      # @param errors [Boolean] false to leave recent errors out, as
      #   +spree info+ does: it runs in its own process, which rarely sees
      #   the server's error log
      # @return [Spree::Diagnostics::Report]
      def report(store: Spree::Store.default, extra_sections: [], errors: true)
        Report.new(generated_at: Time.current, errors: (recent_errors if errors),
                   sections: sections_for(store) + extra_sections.map { |section| extra_section(section) })
      end

      private

      def sections_for(store)
        Spree.diagnostics_sections.filter_map do |class_name|
          section = class_name.to_s.constantize.new(store)
          { key: section.key, title: section.title, rows: section.to_rows }
        rescue StandardError
          { key: class_name.to_s.demodulize.underscore, title: class_name.to_s.demodulize.titleize,
            rows: [{ label: 'Error', value: 'This section could not be read' }] }
        end
      end

      def extra_section(section)
        title = section[:title].to_s
        rows = section[:rows].to_h.map { |label, value| { label: label.to_s, value: value.to_s } }
        { key: title.parameterize(separator: '_'), title: title, rows: rows }
      end

      # A failing cache must not take the rest of the report down with it.
      def recent_errors
        ErrorLog.entries.map { |entry| entry.except(:fingerprint) }
      rescue StandardError
        []
      end
    end
  end
end

module Spree
  class Diagnostics
    # The most recent Spree errors, for the diagnostics report. Subscribed to
    # the Rails error reporter, so it sees what Spree reports with
    # +Rails.error.report+ as well as unhandled request and job errors.
    #
    # Only the exception class and where it was raised are kept, never the
    # message: messages carry customer data (emails, addresses, values echoed
    # from a row) and the report ends up in a public issue. Frames from the
    # host application become +app/[redacted]+ and frames from private gems
    # +gem/[redacted]+, so the merchant's own code is not shared either.
    #
    # Entries live in Rails.cache, so a cache clear empties the log. With a
    # per-process memory store a restart does too, and each process keeps its
    # own.
    class ErrorLog
      CACHE_KEY = 'spree/diagnostics/errors'.freeze
      LIMIT = 50
      FRAME_LIMIT = 10
      HOST_FRAME = 'app/[redacted]'.freeze
      PRIVATE_FRAME = 'gem/[redacted]'.freeze
      RECORDING = :spree_diagnostics_error_log_recording

      # One backtrace line, as the report shows it.
      Frame = Struct.new(:text, :spree, :host)

      class << self
        # @return [Array<Hash>] newest first
        def entries
          Array(Rails.cache.read(CACHE_KEY)).sort_by { |entry| entry[:last_seen_at] }.reverse
        end

        # @return [void]
        def clear
          Rails.cache.delete(CACHE_KEY)
        end

        # Gem directories and the application's, longest first, so a path is
        # matched by the most specific root: a gem vendored inside the app is
        # that gem, and an app inside a gem's directory (a test dummy app) is
        # the app. Built once per process, since every reported error needs it.
        #
        # @return [Array<Array(String, Proc)>] path prefix and the frame it makes
        def roots
          @roots ||= Gem.loaded_specs.values.map { |spec| [spec.full_gem_path + File::SEPARATOR, gem_frame(spec)] }.
                     push([Rails.root.to_s + File::SEPARATOR, ->(_) { Frame.new(HOST_FRAME, false, true) }]).
                     sort_by { |root, _| -root.length }
        end

        private

        def gem_frame(spec)
          return ->(_) { Frame.new(PRIVATE_FRAME, false, false) } unless Stack.public_gem?(spec)

          spree = Stack.spree_gem?(spec)
          ->(relative) { Frame.new("#{spec.name}-#{spec.version}/#{relative}", spree, false) }
        end
      end

      # Rails error subscriber interface. Leaves out refused requests: an
      # error Rails answers with a 4xx (an invalid record, a missing one, a
      # bad parameter) is the client's, not a bug. Never raises, and never
      # recurses: a cache store that reports its own failure to Rails.error
      # would otherwise call back in here.
      def report(error, context:, source: nil, **)
        return if Thread.current[RECORDING] || client_error?(error)

        recording do
          frames = frames_for(error)
          record(error.class.name, source, frames, request_id(context)) if spree_error?(source, frames)
        end
      rescue StandardError
        nil
      end

      private

      # Only the outermost call clears the flag: a nested call that returned
      # early would otherwise re-arm recursion for the rest of the outer one.
      def recording
        Thread.current[RECORDING] = true
        yield
      ensure
        Thread.current[RECORDING] = nil
      end

      def record(error_class, source, frames, request_id)
        now = Time.current.iso8601
        fingerprint = [error_class, (frames.find(&:spree) || frames.first)&.text].join('|')
        entries = Array(Rails.cache.read(CACHE_KEY))
        entry = entries.find { |existing| existing[:fingerprint] == fingerprint }

        if entry
          entry.merge!(count: entry[:count] + 1, last_seen_at: now, request_id: request_id || entry[:request_id])
        else
          entries << { fingerprint: fingerprint, error_class: error_class, source: source, frames: frames.map(&:text),
                       request_id: request_id, count: 1, first_seen_at: now, last_seen_at: now }
        end

        kept = entries.sort_by { |existing| existing[:last_seen_at] }.last(LIMIT)
        Rails.cache.write(CACHE_KEY, kept)
      end

      # Spree's when Spree reported it, or when Spree code ran between the
      # raise and the host application. Every request also passes through
      # Spree's middleware further out, so frames past the first host
      # application frame don't count: an error raised in the merchant's own
      # controller is theirs.
      def spree_error?(source, frames)
        source.to_s.start_with?('spree') || frames.take_while { |frame| !frame.host }.any?(&:spree)
      end

      # Where the error was raised, then every Spree frame and the host
      # application's (collapsed), so the Spree line that led to a library
      # error isn't pushed out by the library's own frames. Ruby's own frames
      # are dropped.
      def frames_for(error)
        origin, *rest = Array(error.backtrace).filter_map { |line| frame(line) }
        [origin, *rest.select { |frame| frame.spree || frame.host }].compact.
          chunk_while { |a, b| a.host && b.host }.map(&:first).first(FRAME_LIMIT)
      end

      def frame(line)
        path = line.sub(/:in .*\z/, '')
        root, make = self.class.roots.find { |prefix, _| path.start_with?(prefix) }
        make&.call(path.delete_prefix(root))
      end

      def client_error?(error)
        ActionDispatch::ExceptionWrapper.status_code_for_exception(error.class.name) < 500
      end

      def request_id(context)
        controller = context[:controller]
        context[:request_id] || (controller.request.request_id if controller.respond_to?(:request))
      end
    end
  end
end

module Spree
  module Api
    # Serves a built React Dashboard (`vite build` output) at /dashboard — the
    # single-node topology: the SPA and the Admin API share one origin, so no
    # CORS entries and Lax cookies. The dist directory comes from
    # `Spree::Config.dashboard_dist_path` (the official Docker image sets it
    # via SPREE_DASHBOARD_DIST_PATH); when unset, /dashboard 404s.
    #
    # SPA semantics: real files are served with long-lived caching (Vite's
    # `assets/` are content-hashed, so they're immutable); every other path
    # falls back to index.html with no-cache so deploys take effect on the
    # next navigation. No authentication — the bundle is public client code;
    # the SPA authenticates its API calls itself.
    class DashboardAppController < ActionController::API
      def show
        root = dist_root
        return head :not_found unless root

        if (file = resolve_file(root, params[:path].to_s))
          response.headers['Cache-Control'] = cache_control_for(params[:path].to_s)
          send_file file, disposition: 'inline'
        elsif (index = root.join('index.html')).file?
          response.headers['Cache-Control'] = 'no-cache'
          send_file index, type: 'text/html', disposition: 'inline'
        else
          head :not_found
        end
      end

      private

      def dist_root
        path = Spree::Config.dashboard_dist_path.presence || ENV.fetch('SPREE_DASHBOARD_DIST_PATH', nil)
        return if path.blank?

        root = Pathname.new(path).expand_path
        root if root.directory?
      end

      # Resolve a request path to a real file inside the dist directory,
      # rejecting anything that escapes it (`..`, absolute paths, symlinks
      # pointing outside are covered by the expanded-path prefix check).
      def resolve_file(root, relative_path)
        return if relative_path.blank?

        candidate = root.join(relative_path).expand_path
        return unless candidate.to_s.start_with?("#{root}#{File::SEPARATOR}")

        candidate if candidate.file?
      end

      def cache_control_for(relative_path)
        if relative_path.start_with?('assets/')
          'public, max-age=31536000, immutable'
        else
          'public, max-age=3600'
        end
      end
    end
  end
end

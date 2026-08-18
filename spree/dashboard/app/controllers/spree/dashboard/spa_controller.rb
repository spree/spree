module Spree
  module Dashboard
    # Serves a built Vite SPA from a directory on disk — the single-node
    # topology, where the SPA and the API it calls share one origin, so no
    # CORS entries and Lax cookies.
    #
    # Abstract: a subclass names the directory by implementing `dist_path`.
    # Two panels ride on this — the operator's dashboard at /dashboard and the
    # marketplace seller panel at /sellers — and they differ in nothing but
    # that directory and their mount point.
    #
    # SPA semantics: real files are served with long-lived caching (Vite's
    # `assets/` are content-hashed, so they're immutable); every other path
    # falls back to index.html with no-cache so deploys take effect on the
    # next navigation. No authentication — the bundle is public client code;
    # the SPA authenticates its API calls itself.
    class SpaController < ActionController::Base
      # GET-only file serving mutates nothing, but enable forgery protection
      # anyway so the controller stays safe if an action is ever added.
      protect_from_forgery with: :exception
      # `verify_same_origin_request` blocks JavaScript responses to plain GET
      # requests — protection against JSONP-style data leaks from dynamically
      # generated JS. The Vite bundle is static public code that the SPA's own
      # <script> tags must load, which is exactly that request shape.
      skip_after_action :verify_same_origin_request

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

      # @return [String, nil] directory holding the built bundle
      def dist_path
        raise NotImplementedError, "#{self.class} must implement #dist_path"
      end

      def dist_root
        path = dist_path
        return if path.blank?

        root = Pathname.new(path).expand_path
        root if root.directory?
      end

      # Resolve a request path to a real file inside the dist directory.
      # Defense in depth against traversal: reject null bytes, absolute
      # paths, and any `.`/`..` segment before touching the filesystem, then
      # verify the expanded path still lives under the dist root (which also
      # covers symlinks pointing outside it).
      def resolve_file(root, relative_path)
        return if relative_path.blank? || relative_path.include?("\0")

        relative = Pathname.new(relative_path)
        return if relative.absolute?

        segments = relative.each_filename.to_a
        return if segments.empty? || segments.any? { |segment| segment == '.' || segment == '..' }

        candidate = root.join(*segments).expand_path
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

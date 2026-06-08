# frozen_string_literal: true

require_relative '../model/model_generator'

module Spree
  # spree:api_resource — scaffold a complete v3-conformant API resource on
  # top of `spree:model`.
  #
  #   bin/rails g spree:api_resource Brand name:string:uniq active:boolean --writable
  #
  # Inherits from Spree::ModelGenerator (model + migration with Spree
  # conventions: prefixed IDs, spree_-prefixed tables, null: false, optional
  # acts_as_paranoid + Spree::Metafields). Adds on top:
  #
  #   - Store + Admin controllers     (managed — overwrite on re-run)
  #   - Store + Admin serializers     (managed — overwrite on re-run)
  #   - Factory                       (managed — overwrite on re-run)
  #   - Controller specs              (managed — overwrite on re-run)
  #   - Routes                        (idempotent inject between sentinels)
  #
  # Owned-once contract: if the model file already exists, the generator
  # leaves it (and the migration) alone — domain code is yours after
  # creation. Re-running adds/updates API surfaces only.
  #
  # TypeScript types and Zod schemas regenerate automatically via the
  # Lefthook pre-commit hook when a serializer file is staged.
  #
  # See docs/plans/spree-dev-cli-and-generators.md (Track 3) for the
  # owned-once / managed-forever / append-only contract.
  class ApiResourceGenerator < Spree::ModelGenerator
    # API-specific templates live alongside this generator. Parent's
    # templates (model.rb.tt, create_table_migration.rb.tt) are inherited
    # via Spree::ModelGenerator.source_paths.
    def self.source_paths
      [File.expand_path('templates', __dir__), *superclass.source_paths]
    end

    class_option :store,
                 type: :boolean,
                 default: true,
                 desc: 'Generate Store API controller + serializer'

    class_option :admin,
                 type: :boolean,
                 default: true,
                 desc: 'Generate Admin API controller + serializer'

    class_option :store_name,
                 type: :string,
                 desc: 'Expose Store API under a different name (e.g. Brand → Discount)'

    class_option :writable,
                 type: :boolean,
                 default: false,
                 desc: 'Make the Store API writable (create/update/destroy)'

    class_option :skip_routes,
                 type: :boolean,
                 default: false,
                 desc: "Don't inject routes into spree/api/config/routes.rb"

    class_option :skip_specs,
                 type: :boolean,
                 default: false,
                 desc: "Don't generate controller specs"

    # api_resource generates its own controller specs and factory directly,
    # so we remove the parent's spec/fixture hooks. Otherwise Rails would
    # invoke rspec (boots Rails → PendingMigrationError on the freshly-
    # created migration; or "[not found]" warning on re-runs).
    remove_hook_for :test_framework
    remove_hook_for :fixture_replacement if hooks[:fixture_replacement]

    # Re-runs are part of the contract (owned-once gating skips the model
    # and migration). Rails' NamedBase collision check would otherwise abort
    # the second run with "Spree::Brand is already used in your application".
    class_option :skip_collision_check, type: :boolean, default: true, desc: false

    desc 'Scaffold a complete v3-conformant API resource (model + migration + controllers + serializers + routes + factory + specs)'

    # --- Owned-once gating ---
    #
    # Thor's parent commands run BEFORE subclass commands (commands merge
    # from superclass first). So we can't snapshot model existence in a
    # subclass action and have parent's create_model_file see it. We
    # capture state in initialize, before any action runs.

    def initialize(*args)
      super
      @model_existed_before_run = File.exist?(model_file_destination)
    end

    # Override parent: skip if the model file already exists. Re-running
    # never overwrites domain code.
    def create_model_file
      if @model_existed_before_run
        say_status :skip, "model #{model_file_destination} (owned-once; already exists)", :yellow
        return
      end
      super
    end

    # Override parent: skip if the model existed before this run. Migrations
    # are append-only — schema changes get a separate migration:
    #   pnpm exec spree rails g migration AddFooToBar foo:string
    def create_migration_file
      if @model_existed_before_run
        say_status :skip, 'migration (model already exists; add a new migration for schema changes)', :yellow
        return
      end
      super
    end

    # --- API surface ---

    def create_store_controller
      return unless options[:store]

      template 'store_controller.rb.tt', store_controller_path
    end

    def create_admin_controller
      return unless options[:admin]

      template 'admin_controller.rb.tt', admin_controller_path
    end

    def create_store_serializer
      return unless options[:store]

      template 'store_serializer.rb.tt', store_serializer_path

      # --store-name aliases the store-facing class under a different name
      # (e.g. Brand → Discount) while keeping the model/table internal.
      if store_external_name != bare_class_name
        template 'store_aliased_serializer.rb.tt',
                 "app/serializers/spree/api/v3/#{store_external_name.underscore}_serializer.rb"
      end
    end

    def create_admin_serializer
      return unless options[:admin]

      template 'admin_serializer.rb.tt', admin_serializer_path
    end

    def create_factory
      template 'factory.rb.tt', "lib/spree/testing_support/factories/#{singular_name}_factory.rb"
    end

    def create_controller_specs
      return if options[:skip_specs]

      if options[:store]
        template 'store_controller_spec.rb.tt',
                 "spec/controllers/spree/api/v3/store/#{plural_name}_controller_spec.rb"
      end
      if options[:admin]
        template 'admin_controller_spec.rb.tt',
                 "spec/controllers/spree/api/v3/admin/#{plural_name}_controller_spec.rb"
      end
    end

    def inject_routes
      return if options[:skip_routes]

      routes_file = api_routes_path

      unless File.exist?(routes_file) && File.writable?(routes_file)
        say_status :skip, "routes.rb at #{routes_file} (not writable — only edge installs can modify gem source)", :yellow
        return
      end

      inject_route_for(:store, store_route_line) if options[:store]
      inject_route_for(:admin, admin_route_line) if options[:admin]
    end

    def print_summary
      say ''
      say "✓ Generated Spree::#{bare_class_name} API resource", :green
      say ''
      say "  Prefixed ID:  #{id_prefix}_xxxxxxxxxx  (edit `has_prefix_id` in the model to change)"
      if store_external_name != bare_class_name
        say "  Store API:    /api/v3/store/#{store_external_plural}  (aliased from #{bare_class_name})"
      elsif options[:store]
        say "  Store API:    /api/v3/store/#{plural_name}  (#{writable? ? 'full CRUD' : 'read-only'})"
      end
      say "  Admin API:    /api/v3/admin/#{plural_name}  (full CRUD)" if options[:admin]
      say ''
      say '  Next steps:', :yellow
      say '    1. Review the generated model — add validations, scopes, callbacks'
      say '    2. Apply the migration:  pnpm exec spree migrate'
      say '    3. Set up authorization (CanCanCan ability) for the resource'
      say '    4. Decide whether this resource is store-scoped (add `has_many` on Store)'
      if options[:store] || options[:admin]
        say '    5. Run the specs:  pnpm exec spree exec bundle exec rspec spec/controllers/spree/api/v3/'
      end
      say ''
    end

    # --- Helpers exposed to templates and other actions ---

    no_tasks do
      def writable?
        options[:writable]
      end

      # NamedBase's class_name includes the namespace prefix (e.g. Spree::Brand
      # when class_path is forced to ["spree"]). Templates that nest under
      # `module Spree` need the bare name to avoid Spree::Spree::Brand.
      def bare_class_name
        class_name.demodulize
      end

      # The external name the Store API surfaces this as. Defaults to the
      # canonical class name; --store-name overrides (e.g. Brand → Discount).
      def store_external_name
        options[:store_name] || bare_class_name
      end

      def store_external_plural
        store_external_name.tableize
      end

      # Used in templates that refer to the resource by singular/plural
      # snake_case identifiers (factory names, file names, route names).
      def singular_name
        file_name
      end

      def plural_name
        file_name.pluralize
      end

      # Attributes the controller permits on write. By default, every column
      # except references (FKs come through nested), attachments, rich text.
      def permitted_attribute_names
        attributes
          .reject { |a| a.reference? || a.attachment? || a.attachments? || a.rich_text? || a.token? || a.password_digest? }
          .map(&:name)
      end
    end

    private

    # Where the model file lands. We use parent's class_path + file_name so
    # this stays in sync with whatever Spree::ModelGenerator decides.
    def model_file_destination
      File.join('app/models', class_path, "#{file_name}.rb")
    end

    def store_controller_path
      "app/controllers/spree/api/v3/store/#{plural_name}_controller.rb"
    end

    def admin_controller_path
      "app/controllers/spree/api/v3/admin/#{plural_name}_controller.rb"
    end

    def store_serializer_path
      "app/serializers/spree/api/v3/#{singular_name}_serializer.rb"
    end

    def admin_serializer_path
      "app/serializers/spree/api/v3/admin/#{singular_name}_serializer.rb"
    end

    # Absolute path to spree_api's routes.rb. On edge installs (SPREE_PATH set)
    # this resolves to the monorepo source; on a published-gem install it
    # resolves to the gem cache directory (typically read-only).
    def api_routes_path
      File.join(Gem.loaded_specs['spree_api'].full_gem_path, 'config/routes.rb')
    end

    # The routes line we inject into the Store namespace.
    # --writable expands to full CRUD; default is read-only (index/show).
    def store_route_line
      if store_external_name != bare_class_name
        # --store-name Discount: alias under a different external name,
        # but route to the canonical controller (brands).
        if writable?
          "        resources :#{store_external_plural}, controller: '#{plural_name}'"
        else
          "        resources :#{store_external_plural}, controller: '#{plural_name}', only: [:index, :show]"
        end
      elsif writable?
        "        resources :#{plural_name}"
      else
        "        resources :#{plural_name}, only: [:index, :show]"
      end
    end

    # Admin always gets full CRUD.
    def admin_route_line
      "        resources :#{plural_name}"
    end

    # The 8-space-indented sentinel markers.
    BEGIN_MARKER = '        # BEGIN spree:api_resource managed routes'.freeze
    END_MARKER   = '        # END spree:api_resource managed routes'.freeze

    # Idempotent injection. First run: insert sentinels + the route line at
    # the top of the namespace. Subsequent runs: find the existing sentinels
    # and insert the route line between them only if not already present.
    def inject_route_for(namespace, route_line)
      file = api_routes_path
      content = File.read(file)

      sentinel_pattern = sentinel_pattern_for(namespace)

      if content =~ sentinel_pattern
        # Sentinels exist for this namespace — find the block, check if
        # `resources :<plural>` is already there.
        block = Regexp.last_match(0)
        if block.include?(route_line.strip)
          say_status :identical, "routes.rb (#{namespace}: #{route_line.strip})", :blue
          return
        end

        # Insert just above the END marker, preserving the existing block.
        new_block = block.sub(END_MARKER, "#{route_line}\n#{END_MARKER}")
        File.write(file, content.sub(block, new_block))
        say_status :inject, "routes.rb (#{namespace}: #{route_line.strip})", :green
      else
        # First run for this namespace — inject the full block right after
        # the namespace's opening line.
        opening = "      namespace :#{namespace} do\n"
        new_block = "#{BEGIN_MARKER}\n#{route_line}\n#{END_MARKER}\n\n"
        File.write(file, content.sub(opening, opening + new_block))
        say_status :inject, "routes.rb (#{namespace}: sentinels + #{route_line.strip})", :green
      end
    end

    # Match the BEGIN…END block scoped to a specific namespace. Anchors on
    # the namespace's opening line so we don't accidentally match the Admin
    # block when looking at Store and vice versa.
    def sentinel_pattern_for(namespace)
      /#{Regexp.escape("namespace :#{namespace} do")}.*?#{Regexp.escape(BEGIN_MARKER)}.*?#{Regexp.escape(END_MARKER)}/m
    end
  end
end

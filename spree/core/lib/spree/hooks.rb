module Spree
  # Extension hook registry for Spree::Workflow flows (see
  # docs/plans/6.0-service-workflows.md). Keys are dotted strings —
  # '<workflow key>.<hook name>', e.g. 'carts.add_item.after_item_added'.
  # Handlers are stored as class names (constantized at dispatch) so
  # registration is initializer-safe, dev-reload-safe and idempotent;
  # blocks are accepted for one-line glue.
  class Hooks
    class UnknownHookError < StandardError; end

    # Reported (never raised) when two context-hook handlers set the same key.
    class ContextCollision < StandardError; end

    def initialize
      @handlers = Hash.new { |hash, key| hash[key] = [] }
      # workflow key => workflow class name; populated by Spree::Workflow
      # when a class declares hooks. Class NAMES, never classes — reload
      # safety.
      @workflows = {}
    end

    attr_reader :workflows

    # @param key [String] '<workflow key>.<hook name>'
    # @param handler [Class, String, nil] class responding to call(context)
    def register(key, handler = nil, &block)
      key = key.to_s
      callable = block || handler
      raise ArgumentError, 'Pass a handler class or a block' if callable.nil?

      entry = callable.is_a?(Proc) ? callable : callable.to_s
      @handlers[key] << entry unless @handlers[key].include?(entry)
      entry
    end

    def unregister(key, handler = nil)
      return @handlers.delete(key.to_s) if handler.nil?

      @handlers[key.to_s].delete(handler.is_a?(Proc) ? handler : handler.to_s)
    end

    # @return [Array<#call>] resolved handlers for the key
    def for(key)
      @handlers[key.to_s].map { |entry| entry.is_a?(Proc) ? entry : entry.constantize.new }
    end

    # Calls every handler registered for the key and deep-merges the hashes
    # they return, so context hooks (set_pricing_context, get_provider_data)
    # can feed data into a calculation without sharing mutable state.
    # Handlers returning anything other than a Hash contribute nothing —
    # lifecycle handlers routinely return whatever their last expression was.
    #
    # @return [Hash] merged contributions; empty when no handler contributed
    def dispatch(key, context)
      self.for(key).each_with_object({}) do |handler, merged|
        contribution = handler.call(context)
        next unless contribution.is_a?(Hash)

        report_collisions(key, merged, contribution)
        merged.deep_merge!(contribution)
      end
    end

    # Registered by Spree::Workflow at class-definition time.
    def register_workflow(workflow_key, class_name)
      @workflows[workflow_key.to_s] = class_name.to_s
    end

    # Validates every registered key against hooks declared by workflow
    # classes. Call after eager load — a typo fails the boot instead of
    # never firing.
    def validate!
      @handlers.keys.each do |key|
        workflow_key, hook_name = split_key(key)
        workflow = @workflows[workflow_key]&.safe_constantize
        raise UnknownHookError, "Hook '#{key}' does not match any registered workflow" if workflow.nil?

        unless workflow.declared_hooks.include?(hook_name.to_sym)
          raise UnknownHookError,
                "Workflow '#{workflow_key}' declares no hook '#{hook_name}' (declared: #{workflow.declared_hooks.join(', ')})"
        end
      end
      true
    end

    def keys
      @handlers.keys
    end

    def clear!
      @handlers.clear
    end

    # Introspection facade: Spree.hooks.carts => { 'carts.add_item' => [...] }
    def method_missing(name, *args, &block)
      prefix = "#{name}."
      matching = @workflows.keys.select { |workflow_key| workflow_key.start_with?(prefix) || workflow_key == name.to_s }
      return super if matching.empty? && !@workflows.keys.any? { |k| k.start_with?(prefix) }

      matching.index_with do |workflow_key|
        workflow = @workflows[workflow_key]&.safe_constantize
        workflow ? workflow.declared_hooks : []
      end
    end

    def respond_to_missing?(name, include_private = false)
      prefix = "#{name}."
      @workflows.keys.any? { |workflow_key| workflow_key.start_with?(prefix) } || super
    end

    private

    # Last writer wins on a collision, which is only defensible if it's
    # visible — two extensions silently fighting over one key is the failure
    # mode this whole contract exists to avoid.
    def report_collisions(key, merged, contribution)
      collisions = merged.keys & contribution.keys
      return if collisions.empty?

      Rails.error.report(
        Spree::Hooks::ContextCollision.new(
          "Hook '#{key}' handlers both set: #{collisions.join(', ')} — last registered handler wins"
        ),
        context: { hook: key, keys: collisions },
        source: 'spree.hooks',
        handled: true
      )
    end

    def split_key(key)
      parts = key.to_s.split('.')
      [parts[0..-2].join('.'), parts[-1]]
    end
  end

  def self.hooks
    @hooks ||= Hooks.new
  end
end

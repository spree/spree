module Compass
  class Logger

    DEFAULT_ACTIONS = [:directory, :exists, :remove, :create, :overwrite, :compile]

    attr_accessor :actions, :options

    def initialize(*actions)
      self.options = actions.last.is_a?(Hash) ? actions.pop : {}
      @actions = DEFAULT_ACTIONS.dup
      @actions += actions
    end

    # Record an action that has occurred
    def record(action, *arguments)
      log "#{action_padding(action)}#{action} #{arguments.join(' ')}"
    end

    # Emit a log message
    def log(msg)
      puts msg
    end

    # add padding to the left of an action that was performed.
    def action_padding(action)
      ' ' * [(max_action_length - action.to_s.length), 0].max
    end

    # the maximum length of all the actions known to the logger.
    def max_action_length
      @max_action_length ||= actions.inject(0){|memo, a| [memo, a.to_s.length].max}
    end
  end
end

# Redefine instead of chain a Rake task
# http://www.bigbold.com/snippets/posts/show/2032

module Rake
  module TaskManager
    def redefine_task(task_class, args, &block)
      task_name, deps = resolve_args(args)
      task_name = task_class.scope_name(@scope, task_name)
      deps = [deps] unless deps.respond_to?(:to_ary)
      deps = deps.collect {|d| d.to_s }
      task = @tasks[task_name.to_s] = task_class.new(task_name, self)
      task.application = self
      task.add_comment(@last_comment)
      @last_comment = nil
      task.enhance(deps, &block)
      task
    end
  end
  class Task
    class << self
      def redefine_task(args, &block)
        Rake.application.redefine_task(self, args, &block)
      end
    end
  end
end

class Object
  def silently
    stderr, stdout, $stderr, $stdout = $stderr, $stdout, StringIO.new, StringIO.new
    yield
    $stderr, $stdout = stderr, stdout
  end
end

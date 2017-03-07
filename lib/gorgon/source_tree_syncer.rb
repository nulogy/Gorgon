require 'open4'
require 'ostruct'

module Gorgon
  class SourceTreeSyncer
    RSYNC_TRANSPORT_SSH = 'ssh'
    RSYNC_TRANSPORT_ANONYMOUS = 'anonymous'
    SYS_COMMAND = 'rsync'
    OPTS = '-azr --timeout=5 --delete'
    RSH_OPTS = 'ssh -o NumberOfPasswordPrompts=0 -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i gorgon.pem'
    EXCLUDE_OPT = '--exclude'
    BLANK_SOURCE_TREE_ERROR = "Source tree path cannot be blank. Check your gorgon.json file."

    attr_reader :source_tree_path, :exclude, :rsync_transport, :tempdir

    def initialize(sync_config)
      sync_config ||= {}
      @source_tree_path = sync_config[:source_tree_path].to_s
      @exclude          = sync_config[:exclude]
      @rsync_transport  = sync_config[:rsync_transport]
    end

    # Pulls the source code to <tt>./gorgon/</tt> temporary directory from
    # <tt>source_tree_path</tt> and calls the passed <tt>block</tt>.
    #
    # The temporary directory is removed after <tt>block</tt> is called even if
    # an exception is raised by the <tt>block</tt>.
    #
    # Returns and yields an object that represents executed command context for
    # pulling the source code. It has following attributes:
    #
    # - <tt>execution_context.command</tt>: The command that was executed
    # - <tt>execution_context.success</tt>: <tt>true</tt> if command execution
    #   returned exit status of 0, <tt>false</tt> otherwise.
    # - <tt>execution_context.output</tt>: Output written on standard output
    #   by the command during execution.
    # - <tt>execution_context.errors</tt>: Output written on standard error by
    #   the command during execution.
    def pull
      source = source_tree_path + "/"
      command = make_command(source, ".")
      if blank_source_tree_path?
        execution_context = prepare_execution_context(command, false, output: nil, errors: BLANK_SOURCE_TREE_ERROR)
        yield(execution_context) if block_given?
        return execution_context
      end

      @tempdir = Dir.mktmpdir("gorgon")
      Dir.chdir(@tempdir)

      execution_context = execute_command(command)
      begin
        yield(execution_context) if block_given?
      ensure
        cleanup
      end

      execution_context
    end

    # Pushes the source code to <tt>source_tree_path</tt>.
    #
    # Returns an object that represents executed command context for
    # pushing the source code. It has following attributes:
    #
    # - <tt>execution_context.command</tt>: The command that was executed
    # - <tt>execution_context.success</tt>: <tt>true</tt> if command execution
    #   returned exit status of 0, <tt>false</tt> otherwise.
    # - <tt>execution_context.output</tt>: Output written on standard output
    #   by the command during execution.
    # - <tt>execution_context.errors</tt>: Output written on standard error by
    #   the command during execution.
    def push
      command = make_command('.', source_tree_path)
      return prepare_execution_context(command, false, output: nil, errors: BLANK_SOURCE_TREE_ERROR) if blank_source_tree_path?

      execute_command(command)
    end

    private

    def cleanup
      FileUtils::remove_entry_secure(tempdir) if tempdir
    end

    def make_command(source, destination)
      "#{SYS_COMMAND} #{rsync_options} #{source} #{destination}"
    end

    def execute_command(command)
      pid, stdin, stdout, stderr = Open4::popen4(command)
      stdin.close

      ignore, status = Process.waitpid2 pid

      output, errors = [stdout, stderr].map { |p| begin p.read ensure p.close end }
      success = (status.exitstatus == 0)

      prepare_execution_context(command, success, output: output, errors: errors)
    end

    def prepare_execution_context(command, success, output: nil, errors: nil)
      context = OpenStruct.new

      context.command = command
      context.success = success
      context.output  = output
      context.errors  = errors

      context.freeze
    end

    def blank_source_tree_path?
      source_tree_path.strip.empty?
    end

    def rsync_options
      if rsync_transport == RSYNC_TRANSPORT_SSH
        "#{OPTS} #{exclude_options} --rsh='#{RSH_OPTS}'"
      else
        "#{OPTS} #{exclude_options}"
      end
    end

    def exclude_options
      return "" if exclude.nil? or exclude.empty?

      ([""] + exclude).join(" #{EXCLUDE_OPT} ")
    end
  end
end

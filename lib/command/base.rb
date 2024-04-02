require_relative '../color'
require_relative '../pager'

module Command
  class Base
    attr_reader :status

    def initialize(dir, env, args, stdin, stdout, stderr)
      @dir = dir
      @env = env
      @args = args
      @stdin = stdin
      @stdout = stdout
      @stderr = stderr
      @isatty = @stdout.isatty
    end

    def fmt(style, string)
      @isatty ? Color.format(style, string) : string
    end

    def setup_pager
      return if defined? @pager
      return unless @isatty

      @pager = Pager.new(@env, @stdout, @stderr)
      @stdout = @pager.input
    end

    def repo
      @repo ||= Repository.new(Pathname.new(@dir).join('.git'))
    end

    def expanded_pathname(path)
      Pathname.new(File.expand_path(path, @dir))
    end

    def exit(status = 0)
      @status = status
      throw :exit
    end

    def execute
      catch(:exit) { run }

      return unless defined? @pager

      @stdout.close_write
      @pager.wait
    end

    def puts(string)
      @stdout.puts(string)
    rescue Errno::EPIPE
      exit 0
    end

    def warn(string)
      @stderr.puts(string)
    rescue Errno::EPIPE
      exit 0
    end

    def error(string)
      warn(string)
    end
  end
end

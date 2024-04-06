require 'optparse'
require_relative '../color'
require_relative '../editor'
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
      parse_options
      catch(:exit) { run }

      return unless defined? @pager

      @stdout.close_write
      @pager.wait
    end

    def parse_options
      @options = {}
      @parser = OptionParser.new
      define_options
      @parser.parse!(@args)
    end

    def define_options; end

    def puts(string)
      @stdout.puts(string)
    rescue Errno::EPIPE
      exit 0
    end

    def error(string)
      @stderr.puts(string)
    rescue Errno::EPIPE
      exit 0
    end

    def warn(string)
      error(string)
    end

    def edit_file(path)
      Editor.edit(path, editor_command) do |editor|
        yield editor
        editor.close unless @isatty
      end
    end

    def editor_command
      @env['GIT_EDITOR'] || @env['VISUAL'] || @env['EDITOR'] || Editor::DEFAULT_EDITOR
    end
  end
end

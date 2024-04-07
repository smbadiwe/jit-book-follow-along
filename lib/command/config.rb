require_relative '../config'

module Command
  class Config < Base
    def run
      @config = ::Config.new(config_path)

      process_readonly_commands
      process_write_commands

      exit 0
    end

    def define_options
      @options[:local] = true

      @parser.on('--global') { @options[:local] = false }
      @parser.on('--add') { @options[:add] = true }
      @parser.on('--get=<key>') { |key| @options[:get] = key }
      @parser.on('--get-all=<key>') { |key| @options[:get_all] = key }
      @parser.on('--unset-all=<key>') { |key| @options[:unset_all] = key }
      @parser.on('-l', '--list') { @options[:list] = true }

    end

    private

    def process_readonly_commands
      @config.open

      if @options.has_key?(:get)
        puts @config.get(@options[:get])
      elsif @options.has_key?(:get_all)
        @config.get_all(@options[:get_all]).each { |value| puts value }
      end
    end

    def process_write_commands
      @config.open_for_update

      if @options.has_key?(:add)
        key, value = @args
        @config.add(key.strip, value.strip)
      elsif @options.has_key?(:unset_all)
        @config.unset_all(@options[:unset_all])
      end

      @config.save
    end

    def config_path
      if @options[:local]
        repo.git_path.join('config')
      else
        '~/.gitconfig'
      end
    end
  end
end

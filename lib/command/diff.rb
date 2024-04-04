require_relative './shared/print_diff'
    include PrintDiff

    def define_options
      @options[:patch] = true
      define_print_diff_options
      @parser.on '--cached', '--staged' do
        @options[:cached] = true
      return unless @options[:patch]

      return unless @options[:patch]
      
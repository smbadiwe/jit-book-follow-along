module Command
  module PrintDiff
    NULL_OID = '0' * 40
    NULL_PATH = '/dev/null'
    Target = Struct.new(:path, :oid, :mode, :data) do
      def diff_path
        mode ? path : NULL_PATH
      end
    end

    private

    def define_print_diff_options
      @parser.on('-p', '-u', '--patch') { @options[:patch] = true }
      @parser.on('-s', '--no-patch') { @options[:patch] = false }
    end

    def print_diff(a, b)
      return if a.oid == b.oid and a.mode == b.mode

      a.path = Pathname.new('a').join(a.path)

      b.path = Pathname.new('b').join(b.path)
      puts "diff --git #{a.path} #{b.path}"
      print_diff_mode(a, b)
      print_diff_content(a, b)
    end

    def header(string)
      puts fmt(:bold, string)
    end

    def short(oid)
      repo.database.short_oid(oid)
    end

    def print_diff_mode(a, b)
      if a.mode.nil?
        header("new file mode #{b.mode}")
      elsif b.mode.nil?
        header("deleted file mode #{a.mode}")
      elsif a.mode != b.mode
        header("old mode #{a.mode}")
        header("new mode #{b.mode}")
      end
    end

    def print_diff_content(a, b)
      return if a.oid == b.oid

      oid_range = "index #{short a.oid}..#{short b.oid}"
      oid_range.concat(" #{a.mode}") if a.mode == b.mode
      puts oid_range
      puts "--- #{a.diff_path}"
      puts "+++ #{b.diff_path}"
      hunks = ::Diff.diff_hunks(a.data, b.data)
      hunks.each { |hunk| print_diff_hunk(hunk) }
    end

    def print_diff_hunk(hunk)
      puts fmt(:cyan, hunk.header)
      hunk.edits.each { |edit| print_diff_edit(edit) }
    end

    def print_diff_edit(edit)
      text = edit.to_s.rstrip
      case edit.type
      when :eql then puts text
      when :ins then puts fmt(:green, text)
      when :del then puts fmt(:red, text)
      end
    end
  end
end

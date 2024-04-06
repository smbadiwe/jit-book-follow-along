require 'shellwords'

class Editor
  DEFAULT_EDITOR = 'code --wait' # 'vi'
  def self.edit(path, command)
    editor = Editor.new(path, command)
    yield editor
    editor.edit_file
  end

  def initialize(path, command)
    @path = path
    @command = command || DEFAULT_EDITOR
    @closed = false
  end

  def puts(string)
    return if @closed

    file.puts(string)
  end

  def note(string)
    return if @closed

    string.each_line { |line| file.puts("# #{line}") }
  end

  def close
    @closed = true
  end

  def file
    flags = File::WRONLY | File::CREAT | File::TRUNC
    @file ||= File.open(@path, flags)
  end

  def edit_file
    file.close
    editor_argv = Shellwords.shellsplit(@command) + [@path.to_s]
    # raise "There was a problem with the editor '#{@command}'." unless @closed or system(*editor_argv)
    system(*editor_argv) unless @closed

    remove_notes(File.read(@path))
  end

  def remove_notes(string)
    lines = string.lines.reject { |line| line.start_with?('#') }
    if lines.all? { |line| /^\s*$/ =~ line }
      nil
    else
      "#{lines.join('').strip}\n"
    end
  end
end


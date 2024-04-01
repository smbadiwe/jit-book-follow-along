class Workspace
  IGNORE = ['.', '..', '.git', '.vscode', '../.git', '../.vscode']

  MissingFile = Class.new(StandardError)
  NoPermission = Class.new(StandardError)

  def initialize(pathname)
    @pathname = pathname
  end

  def list_files(path = @pathname)
    relative = path.relative_path_from(@pathname)
    if File.directory?(path)
      filenames = Dir.entries(path) - IGNORE
      filenames.flat_map { |name| list_files(path.join(name)) }
    elsif File.exist?(path)
      [relative]
    else
      raise MissingFile, "pathspec '#{relative}' did not match any files"
    end
  end

  # Lists the directory specified by dirname and returns a hash with the relative path of each file as the key and its stats as the value.
  def list_dir(dirname)
    path = @pathname.join(dirname || '')
    entries = Dir.entries(path) - IGNORE
    stats = {}
    entries.each do |name|
      relative = path.join(name).relative_path_from(@pathname)
      stats[relative.to_s] = File.stat(path.join(name))
    end
    stats
  end

  def read_file(path)
    File.read(@pathname.join(path))
  rescue Errno::EACCES
    raise NoPermission, "open('#{path}'): Permission denied"
  end

  def stat_file(path)
    File.stat(@pathname.join(path))
  rescue Errno::EACCES
    raise NoPermission, "stat('#{path}'): Permission denied"
  end
end

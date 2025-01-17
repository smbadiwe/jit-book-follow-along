class Workspace
  IGNORE = ['.', '..', '.git', '.vscode', '../.git', '../.vscode']
  # IGNORE = ['.', '..']  #, '.git', '.vscode', '../.git', '../.vscode']

  MissingFile = Class.new(StandardError)
  NoPermission = Class.new(StandardError)

  def initialize(pathname)
    @pathname = pathname
    get_ignored_paths
  end

  def get_ignored_paths
    @ignored_paths = IGNORE
  #   skipped = read_file('.gitignore').lines
  #   puts "skipped: #{skipped}. @pathname: #{@pathname}"
  #   skipped_clean = []
  #   skipped.each do |line|
  #     full_path = File.expand_path(line.strip, @pathname)
  #     relative = Pathname.new(full_path).relative_path_from(@pathname)
  #     puts "Line: #{line.strip}. (#{relative}) File to ignore: #{full_path}"
  #     next unless File.exist?(full_path)
  #     if File.directory?(full_path)
  #       skipped_clean.push(relative.to_s + File::SEPARATOR)
  #     else
  #       skipped_clean.push(relative.to_s)
  #     end
  #   end
  #   @ignored_paths = IGNORE + skipped_clean
  # rescue
  #   @ignored_paths = IGNORE
  #   raise
  end

  def write_file(path, data, mode = nil, mkdir = false)
    full_path = @pathname.join(path)
    FileUtils.mkdir_p(full_path.dirname) if mkdir
    flags = File::WRONLY | File::CREAT | File::TRUNC
    File.open(full_path, flags) { |f| f.write(data) }
    File.chmod(mode, full_path) if mode
  end

  def list_files(path = @pathname)
    relative = path.relative_path_from(@pathname)
    if File.directory?(path)
      filenames = Dir.entries(path) - @ignored_paths
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
    entries = Dir.entries(path) - @ignored_paths
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

  def stat_file?(path)
    stat_file(path)
    true
  rescue StandardError
    false
  end

  def apply_migration(migration)
    apply_change_list(migration, :delete)
    migration.rmdirs.sort.reverse_each { |dir| remove_directory(dir) }
    migration.mkdirs.sort.each { |dir| make_directory(dir) }
    apply_change_list(migration, :update)
    apply_change_list(migration, :create)
  end

  def apply_change_list(migration, action)
    migration.changes[action].each do |filename, entry|
      path = @pathname.join(filename)
      FileUtils.rm_rf(path)
      next if action == :delete

      flags = File::WRONLY | File::CREAT | File::EXCL
      data = migration.blob_data(entry.oid)
      File.open(path, flags) { |file| file.write(data) }
      File.chmod(entry.mode, path)
    end
  end

  def remove_directory(dirname)
    Dir.rmdir(@pathname.join(dirname))
  rescue Errno::ENOENT, Errno::ENOTDIR, Errno::ENOTEMPTY
  end

  def make_directory(dirname)
    path = @pathname.join(dirname)
    stat = stat_file(dirname)
    File.unlink(path) if stat&.file?
    Dir.mkdir(path) unless stat&.directory?
  end

  def remove(path)
    FileUtils.rm_rf(@pathname.join(path))
    path.dirname.ascend { |dirname| remove_directory(dirname) }
  rescue Errno::ENOENT
  end
end

require_relative './lockfile'

class Refs
  def initialize(pathname)
    @pathname = pathname
    @refs_path = @pathname.join('refs')
    @heads_path = @refs_path.join('heads')
  end

  InvalidBranch = Class.new(StandardError)
  LockDenied = Class.new(StandardError)

  INVALID_NAME = %r{
  ^\.
  | /\.
  | \.\.
  | /$
  | \.lock$
  | @\{
  | [\x00-\x20*:?\[\\^~\x7f]
  }x

  def create_branch(branch_name, start_oid)
    path = @heads_path.join(branch_name)
    raise InvalidBranch, "'#{branch_name}' is not a valid branch name." if INVALID_NAME =~ branch_name
    raise InvalidBranch, "A branch named '#{branch_name}' already exists." if File.file?(path)

    update_ref_file(path, start_oid)
  end

  def update_ref_file(path, oid)
    lockfile = Lockfile.new(path)
    lockfile.hold_for_update
    lockfile.write(oid)
    lockfile.write("\n")
    lockfile.commit
  rescue Lockfile::MissingParent
    FileUtils.mkdir_p(path.dirname)
    retry
  end

  def update_head(oid)
    update_ref_file(head_path, oid)
  end

  def read_head
    return unless File.exist?(head_path)

    File.read(head_path).strip
  end

  def read_ref(name)
    path = path_for_name(name)
    path ? read_ref_file(path) : nil
  end

  private

  def path_for_name(name)
    prefixes = [@pathname, @refs_path, @heads_path]
    prefix = prefixes.find { |path| File.file? path.join(name) }
    prefix ? prefix.join(name) : nil
  end

  def read_ref_file(path)
    File.read(path).strip
  rescue Errno::ENOENT
    nil
  end

  def head_path
    @pathname.join('HEAD')
  end
end

require_relative './database'
require_relative './index'
require_relative './refs'
require_relative './repository/pending_commit'
require_relative './repository/status'
require_relative './workspace'

class Repository
  attr_reader :git_path

  def initialize(git_path)
    @git_path = git_path
  end

  def database
    @database ||= Database.new(@git_path.join('objects'))
  end

  def index
    @index ||= Index.new(@git_path.join('index'))
  end

  def refs
    @refs ||= Refs.new(@git_path)
  end

  def current_branch
    @refs.current_ref().short_name
  end

  def workspace
    @workspace ||= Workspace.new(@git_path.dirname)
  end

  def status
    Status.new(self)
  end

  def migration(tree_diff)
    Migration.new(self, tree_diff)
  end

  def pending_commit
    PendingCommit.new(@git_path)
  end

  def trackable_file?(path, stat)
    return false unless stat
    return !index.tracked?(path) if stat.file?
    return false unless stat.directory?

    items = workspace.list_dir(path)
    files = items.select { |_, item_stat| item_stat.file? }
    dirs = items.select { |_, item_stat| item_stat.directory? }
    [files, dirs].any? do |list|
      list.any? { |item_path, item_stat| trackable_file?(item_path, item_stat) }
    end
  end
end

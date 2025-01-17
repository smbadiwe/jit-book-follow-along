require_relative './inspector'

class Repository
  class Status
    attr_reader :changed,
                :stats,
                :head_tree,
                :index_changes,
                :conflicts,
                :workspace_changes,
                :untracked_files

    def initialize(repository, commit_oid = nil)
      @inspector = Inspector.new(repository)
      @repo = repository
      @stats = {}

      commit_oid ||= @repo.refs.read_head
      @head_tree = @repo.database.load_tree_list(commit_oid)

      @changed = SortedSet.new
      @index_changes = SortedHash.new
      @conflicts = SortedHash.new
      @workspace_changes = SortedHash.new
      @untracked_files = SortedSet.new
      
      scan_workspace
      # load_head_tree
      check_index_entries
      collect_deleted_head_files
    end

    private

    def collect_deleted_head_files
      @head_tree.each_key do |path|
        record_change(path, @index_changes, :deleted) unless @repo.index.tracked_file?(path)
      end
    end

    def scan_workspace(prefix = nil)
      @repo.workspace.list_dir(prefix).each do |path, stat|
        if @repo.index.tracked?(path)
          @stats[path] = stat if stat.file?
          scan_workspace(path) if stat.directory?
        elsif trackable_file?(path, stat)
          # else
          path += File::SEPARATOR if stat.directory?
          @untracked_files.add(path)
        end
      end
    end

    def trackable_file?(path, stat)
      @repo.trackable_file?(path, stat)
    end

    def check_index_entries
      @repo.index.each_entry do |entry|
        if entry.stage == 0
          check_index_against_workspace(entry)
          check_index_against_head_tree(entry)
        else
          @changed.add(entry.path)
          @conflicts[entry.path] ||= []
          @conflicts[entry.path].push(entry.stage)
        end
      end
    end

    def check_index_against_head_tree(entry)
      item = @head_tree[entry.path]
      status = @inspector.compare_tree_to_index(item, entry)
      return unless status

      record_change(entry.path, @index_changes, status)
    end

    def detect_workspace_changes
      @repo.index.each_entry { |entry| check_index_entry(entry) }
    end

    def record_change(path, set, type)
      @changed.add(path)
      set[path] = type
    end

    def check_index_against_workspace(entry)
      stat = @stats[entry.path]
      status = @inspector.compare_index_to_workspace(entry, stat)
      if status
        record_change(entry.path, @workspace_changes, status)
      else
        @repo.index.update_entry_stat(entry, stat)
      end
    end

    # def load_head_tree
    #   @head_tree = {}
    #   head_oid = @repo.refs.read_head
    #   return unless head_oid

    #   commit = @repo.database.load(head_oid)
    #   read_tree(commit.tree)
    # end

    # def read_tree(tree_oid, pathname = Pathname.new(''))
    #   tree = @repo.database.load(tree_oid)
    #   tree.entries.each do |name, entry|
    #     path = pathname.join(name)
    #     if entry.tree?
    #       read_tree(entry.oid, path)
    #     else
    #       @head_tree[path.to_s] = entry
    #     end
    #   end
    # end
  end
end

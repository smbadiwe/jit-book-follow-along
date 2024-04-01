require_relative './base'
require_relative '../database/blob'

module Command
  class Status < Base
    def run
      @stats = {}
      @changed = SortedSet.new
      @changes = Hash.new { |hash, key| hash[key] = Set.new }
      @untracked = SortedSet.new

      repo.index.load_for_update

      scan_workspace
      detect_workspace_changes

      repo.index.write_updates

      print_results
      exit 0
    end

    def print_results
      @changed.each do |path|
        status = status_for(path)
        puts "#{status} #{path}"
      end
      @untracked.each do |path|
        puts "?? #{path}"
      end
    end

    def collect_deleted_head_files
      @head_tree.each_key do |path|
        record_change(path, :index_deleted) unless repo.index.tracked_file?(path)
      end
    end

    def status_for(path)
      changes = @changes[path]
      left = ' '
      left = 'A' if changes.include?(:index_added)
      left = 'M' if changes.include?(:index_modified)

      right = ' '
      right = 'D' if changes.include?(:workspace_deleted)
      right = 'M' if changes.include?(:workspace_modified)
      left + right
    end

    def scan_workspace(prefix = nil)
      repo.workspace.list_dir(prefix).each do |path, stat|
        if repo.index.tracked?(path)
          @stats[path] = stat if stat.file?
          scan_workspace(path) if stat.directory?
        elsif trackable_file?(path, stat)
        # else
          path += File::SEPARATOR if stat.directory?
          @untracked.add(path)
        end
      end
    end

    def load_head_tree
      @head_tree = {}
      head_oid = repo.refs.read_head
      return unless head_oid

      commit = repo.database.load(head_oid)
      read_tree(commit.tree)
    end

    def read_tree(tree_oid, pathname = Pathname.new(''))
      tree = repo.database.load(tree_oid)
      tree.entries.each do |name, entry|
        path = pathname.join(name)
        if entry.tree?
          read_tree(entry.oid, path)
        else
          @head_tree[path.to_s] = entry
        end
      end
    end

    def check_index_entries
      repo.index.each_entry do |entry|
        check_index_against_workspace(entry)
        check_index_against_head_tree(entry)
      end
    end

    def check_index_against_head_tree(entry)
      item = @head_tree[entry.path]
      return if item

      record_change(entry.path, :index_added)
    end

    def check_index_against_head_tree(entry)
      item = @head_tree[entry.path]
      if item
        record_change(entry.path, :index_modified) unless entry.mode == item.mode and entry.oid == item.oid
      else
        record_change(entry.path, :index_added)
      end
    end

    def detect_workspace_changes
      repo.index.each_entry { |entry| check_index_entry(entry) }
    end

    def record_change(path, type)
      @changed.add(path)
      @changes[path].add(type)
    end

    def check_index_entry(entry)
      stat = @stats[entry.path]
      return record_change(entry.path, :workspace_deleted) unless stat
      return record_change(entry.path, :workspace_modified) unless entry.stat_match?(stat)
      return if entry.times_match?(stat) # FIXME: Still needed?

      data = repo.workspace.read_file(entry.path)
      blob = Database::Blob.new(data)
      oid = repo.database.hash_object(blob)

      if entry.oid == oid
        repo.index.update_entry_stat(entry, stat)
      else
        record_change(entry.path, :workspace_modified)
      end
    end

    def trackable_file?(path, stat)
      return false unless stat
      return !repo.index.tracked?(path) if stat.file?
      return false unless stat.directory?

      items = repo.workspace.list_dir(path)
      files = items.select { |_, item_stat| item_stat.file? }
      dirs = items.select { |_, item_stat| item_stat.directory? }
      [files, dirs].any? do |list|
        list.any? { |item_path, item_stat| trackable_file?(item_path, item_stat) }
      end
    end
  end
end
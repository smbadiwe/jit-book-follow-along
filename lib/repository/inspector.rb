class Repository
  class Inspector
    def initialize(repository)
      @repo = repository
    end

    def trackable_file?(path, stat)
      @repo.trackable_file?(path, stat)
    end

    def compare_index_to_workspace(entry, stat)
      return :untracked unless entry
      return :deleted unless stat
      return :modified unless entry.stat_match?(stat)
      return nil if entry.times_match?(stat)

      data = @repo.workspace.read_file(entry.path)
      blob = Database::Blob.new(data)
      oid = @repo.database.hash_object(blob)
      return if entry.oid == oid

      :modified
    end

    def compare_tree_to_index(item, entry)
      return nil unless item or entry
      return :added unless item
      return :deleted unless entry

      return if entry.mode == item.mode and entry.oid == item.oid

      :modified
    end
  end
end

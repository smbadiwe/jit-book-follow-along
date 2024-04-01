require 'pathname'
require_relative './base'
require_relative '../database'
require_relative '../database/blob'
require_relative '../repository'

module Command
  class Add < Base
    LOCKED_INDEX_MESSAGE = <<~MSG
      Another jit process seems to be running in this repository.
      Please make sure all processes are terminated then try again.
      If it still fails, a jit process may have crashed in this
      repository earlier: remove the file manually to continue.
    MSG

    def run
      repo.index.load_for_update
      expanded_paths.each { |path| add_to_index(path) }
      repo.index.write_updates
      exit 0
    rescue Lockfile::LockDenied => e
      handle_locked_index(e)
    rescue Workspace::MissingFile => e
      handle_missing_file(e)
    rescue Workspace::NoPermission => e
      handle_unreadable_file(e)
    end

    private

    def expanded_paths
      @args.flat_map do |path|
        repo.workspace.list_files(expanded_pathname(path))
      end
    end

    def add_to_index(path)
      data = repo.workspace.read_file(path)
      stat = repo.workspace.stat_file(path)
      blob = Database::Blob.new(data)
      repo.database.store(blob)
      repo.index.add(path, blob.oid, stat)
    end

    def handle_locked_index(error)
      error("fatal: #{error.message}\n")
      error(LOCKED_INDEX_MESSAGE)
      exit 128
    end

    def handle_missing_file(error)
      error("fatal: #{error.message}")
      repo.index.release_lock
      exit 128
    end

    def handle_unreadable_file(error)
      error("error: #{error.message}")
      error('fatal: adding files failed')
      repo.index.release_lock
      exit 128
    end
  end
end

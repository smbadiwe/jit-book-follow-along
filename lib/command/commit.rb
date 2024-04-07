require 'pathname'
require_relative './base'
require_relative '../database/author'
require_relative '../database/commit'
require_relative '../database/tree'
require_relative '../repository'
require_relative './shared/write_commit'

module Command
  class Commit < Base
    include WriteCommit
    COMMIT_NOTES = <<~MSG
      Please enter the commit message for your changes. Lines starting
      with '#' will be ignored, and an empty message aborts the commit.
    MSG
    def run
      repo.index.load

      handle_amend if @options[:amend]
      merge_type = pending_commit.merge_type
      resume_merge(merge_type) if merge_type

      parent = repo.refs.read_head
      message = compose_message(read_message || reused_message)
      commit = write_commit([*parent], message)

      print_commit(commit)

      exit 0
    end

    def define_options
      define_write_commit_options
      @parser.on('--amend') { @options[:amend] = true }
      @parser.on '-C <commit>', '--reuse-message=<commit>' do |commit|
        @options[:reuse] = commit
        @options[:edit] = false
      end
      @parser.on '-c <commit>', '--reedit-message=<commit>' do |commit|
        @options[:reuse] = commit
        @options[:edit] = true
      end
    end

    private

    def handle_amend
      old = repo.database.load(repo.refs.read_head)
      tree = write_tree

      message = amend_commit_message(old)
      committer = current_author
      amended = Database::Commit.new(old.parents, tree.oid, old.author, committer, message)

      repo.database.store(amended)
      repo.refs.update_head(amended.oid)
      print_commit(amended)
      exit 0
    end

    def amend_commit_message(oid)
      compose_message(read_message || oid.message)
    end

    def reused_message
      return nil unless @options.has_key?(:reuse)

      revision = Revision.new(repo, @options[:reuse])
      commit = repo.database.load(revision.resolve)
      commit.message
    end

    def compose_message(message)
      edit_file(commit_message_path) do |editor|
        editor.puts(message || '')
        editor.puts('')
        editor.note(COMMIT_NOTES)
        editor.close unless @options[:edit]
      end
    end
  end
end

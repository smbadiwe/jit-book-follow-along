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

    def run
      repo.index.load
      parent = repo.refs.read_head
      message = @stdin.read
      commit = write_commit([*parent], message)
      is_root = parent.nil? ? '(root-commit) ' : ''
      puts "[#{is_root}#{commit.oid}] #{message.lines.first}"
      exit 0
    end
  end
end

require 'pathname'
require_relative './base'
require_relative '../database/author'
require_relative '../database/commit'
require_relative '../database/tree'
require_relative '../repository'

module Command
  class Commit < Base
    def run
      repo.index.load

      root = Database::Tree.build(repo.index.each_entry)
      root.traverse { |tree| repo.database.store(tree) }

      name = @env.fetch('GIT_AUTHOR_NAME', 'Soma Mbadiwe')
      email = @env.fetch('GIT_AUTHOR_EMAIL', 'somasystemsng@gmail.com')
      parent = repo.refs.read_head
      author = Database::Author.new(name, email, Time.now)
      message = @stdin.read

      commit = Database::Commit.new(parent, root.oid, author, message)
      repo.database.store(commit)
      repo.refs.update_head(commit.oid)

      is_root = parent.nil? ? '(root-commit) ' : ''
      puts("[#{is_root}#{commit.oid}] #{message.lines.first}")
      exit 0
    end
  end
end

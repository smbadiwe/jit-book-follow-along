require_relative '../repository/migration'
require_relative '../revision'

module Command
  class Checkout < Base
    def run
      @target = @args[0]

      @current_ref = repo.refs.current_ref
      @current_oid = @current_ref.read_oid

      revision = Revision.new(repo, @target)
      @target_oid = revision.resolve(Revision::COMMIT)

      repo.index.load_for_update

      tree_diff = repo.database.tree_diff(@current_oid, @target_oid)
      migration = repo.migration(tree_diff)
      migration.apply_changes

      repo.index.write_updates
      repo.refs.set_head(@target, @target_oid)
      @new_ref = repo.refs.current_ref

      print_previous_head
      print_detachment_notice
      print_new_head

      exit 0
    rescue Repository::Migration::Conflict
      handle_migration_conflict(migration)
    rescue Revision::InvalidObject => e
      handle_invalid_object(revision, e)
    end

    def define_options; end

    private

    DETACHED_HEAD_MESSAGE = <<~MSG
      You are in 'detached HEAD' state. You can look around, make experimental
      changes and commit them, and you can discard any commits you make in this
      state without impacting any branches by performing another checkout.
      If you want to create a new branch to retain commits you create, you may
      do so (now or later) by using the branch command. Example:
      jit branch <new-branch-name>
    MSG

    def print_detachment_notice
      return unless @new_ref.head? and !@current_ref.head?

      error "Note: checking out '#{@target}'."
      error ''
      error DETACHED_HEAD_MESSAGE
      error ''
    end

    def print_new_head
      if @new_ref.head?
        print_head_position('HEAD is now at', @target_oid)
      elsif @new_ref == @current_ref
        error "Already on '#{@target}'"
      else
        error "Switched to branch '#{@target}'"
      end
    end

    def print_previous_head
      return unless @current_ref.head? and @current_oid != @target_oid

      print_head_position('Previous HEAD position was', @current_oid)
    end

    def print_head_position(message, oid)
      commit = repo.database.load(oid)
      short = repo.database.short_oid(commit.oid)
      error "#{message} #{short} #{commit.title_line}"
    end

    def handle_migration_conflict(migration)
      repo.index.release_lock
      migration.errors.each do |message|
        error "error: #{message}"
      end
      error 'Aborting'
      exit 1
    end

    def handle_invalid_object(revision, error)
      repo.index.release_lock
      revision.errors.each do |err|
        error "error: #{err.message}"
        err.hint.each { |line| error "hint: #{line}" }
      end
      error "error: #{error.message}"
      exit 1
    end
  end
end

module Command
  module Sequencing
    def run
      case @options[:mode]
      when :continue then handle_continue
      when :abort then handle_abort
      when :quit then handle_quit
      end

      sequencer.start(@options)
      store_commit_sequence
      resume_sequencer
    end

    def define_options
      @options[:mode] = :run

      @parser.on('--continue') { @options[:mode] = :continue }
      @parser.on('--abort') { @options[:mode] = :abort }
      @parser.on('--quit') { @options[:mode] = :quit }

      @parser.on '-m <parent>', '--mainline=<parent>', Integer do |parent|
        @options[:mainline] = parent
      end
    end

    def sequencer
      @sequencer ||= Repository::Sequencer.new(repo)
    end

    def select_parent(commit)
      mainline = sequencer.get_option('mainline')
      if commit.merge?
        return commit.parents[mainline - 1] if mainline

        @stderr.puts <<~ERROR
          error: commit #{commit.oid} is a merge but no -m option was given
        ERROR
        exit 1
      else
        return commit.parent unless mainline

        @stderr.puts <<~ERROR
          error: mainline was specified but commit #{commit.oid} is not a merge
        ERROR
        exit 1
      end
    end
    
    CONFLICT_NOTES = <<~MSG
      after resolving the conflicts, mark the corrected paths
      with 'jit add <paths>' or 'jit rm <paths>'
      and commit the result with 'jit commit'
    MSG

    def fail_on_conflict(inputs, message)
      sequencer.dump

      pending_commit.start(inputs.right_oid, merge_type)

      edit_file(pending_commit.message_path) do |editor|
        editor.puts(message)
        editor.puts('')
        editor.note('Conflicts:')
        repo.index.conflict_paths.each { |name| editor.note("\t#{name}") }
        editor.close
      end

      @stderr.puts "error: could not apply #{inputs.right_name}"
      CONFLICT_NOTES.each_line { |line| @stderr.puts "hint: #{line}" }

      exit 1
    end

    def resolve_merge(inputs)
      repo.index.load_for_update
      ::Merge::Resolve.new(repo, inputs).execute
      repo.index.write_updates
    end

    def finish_commit(commit)
      repo.database.store(commit)
      repo.refs.update_head(commit.oid)
      print_commit(commit)
    end

    def resume_sequencer
      loop do
        action, commit = sequencer.next_command
        break unless commit

        case action
        when :pick then pick(commit)
        when :revert then revert(commit)
        end
        sequencer.drop_command
      end
      sequencer.quit
      exit 0
    end

    def handle_continue
      repo.index.load

      case pending_commit.merge_type
      when :cherry_pick then write_cherry_pick_commit
      when :revert then write_revert_commit
      end

      sequencer.load
      sequencer.drop_command
      resume_sequencer
    rescue Repository::PendingCommit::Error => e
      @stderr.puts "fatal: #{e.message}"
      exit 128
    end

    def handle_abort
      pending_commit.clear(merge_type) if pending_commit.in_progress?
      repo.index.load_for_update
      begin
        sequencer.abort
      rescue StandardError => e
        @stderr.puts "warning: #{e.message}"
      end
      repo.index.write_updates
      exit 0
    end

    def handle_quit
      pending_commit.clear(merge_type) if pending_commit.in_progress?
      sequencer.quit
      exit 0
    end
  end
end

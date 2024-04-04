class RevList
  def initialize(repo, revs)
    @repo = repo
    @commits = {}
    @flags = Hash.new { |hash, oid| hash[oid] = Set.new }
    @limited = false
    @output = []
    @queue = []
    revs.each { |rev| handle_revision(rev) }
    handle_revision(Revision::HEAD) if @queue.empty?
  end

  def each(&block)
    limit_list if @limited
    traverse_commits(&block)
  end

  def limit_list
    while still_interesting?
      commit = @queue.shift
      add_parents(commit)
      @output.push(commit) unless marked?(commit.oid, :uninteresting)
    end
    @queue = @output
  end

  private

  RANGE = /^(.*)\.\.(.*)$/
  EXCLUDE = /^\^(.+)$/
  def still_interesting?
    return false if @queue.empty?

    oldest_out = @output.last
    newest_in = @queue.first
    return true if oldest_out and oldest_out.date <= newest_in.date
    return true if @queue.any? { |commit| !marked?(commit.oid, :uninteresting) }

    false
  end

  def handle_revision(rev)
    oid = Revision.new(@repo, rev).resolve(Revision::COMMIT)
    commit = load_commit(oid)
    enqueue_commit(commit)

    if match = RANGE.match(rev)
      # RANGE supports syntax like jit log topic...master
      set_start_point(match[1], false)
      set_start_point(match[2], true)
    elsif match = EXCLUDE.match(rev)
      # EXCLUDE supports syntax like jit log ^topic
      set_start_point(match[1], false)
    else
      set_start_point(rev, true)
    end
  end

  def set_start_point(rev, interesting)
    rev = Revision::HEAD if rev == ''
    oid = Revision.new(@repo, rev).resolve(Revision::COMMIT)
    commit = load_commit(oid)
    enqueue_commit(commit)
    return if interesting

    @limited = true
    mark(oid, :uninteresting)
    mark_parents_uninteresting(commit)
  end

  def mark_parents_uninteresting(commit)
    while commit&.parent
      break unless mark(commit.parent, :uninteresting)

      commit = @commits[commit.parent]
    end
  end

  def load_commit(oid)
    return nil unless oid

    @commits[oid] ||= @repo.database.load(oid)
  end

  def mark(oid, flag)
    @flags[oid].add?(flag)
  end

  def marked?(oid, flag)
    @flags[oid].include?(flag)
  end

  def enqueue_commit(commit)
    return unless mark(commit.oid, :seen)

    index = @queue.find_index { |c| c.date < commit.date }
    @queue.insert(index || @queue.size, commit)
  end

  def traverse_commits
    until @queue.empty?
      commit = @queue.shift
      add_parents(commit) unless @limited
      next if marked?(commit.oid, :uninteresting)
      yield commit
    end
  end

  def add_parents(commit)
    return unless mark(commit.oid, :added)

    parent = load_commit(commit.parent)
    return unless parent

    mark_parents_uninteresting(parent) if marked?(commit.oid, :uninteresting)
    enqueue_commit(parent)
  end
end

class Revision
  Ref = Struct.new(:name) do
    def resolve(context)
      context.read_ref(name)
    end
  end

  Parent = Struct.new(:rev) do
    def resolve(context)
      context.commit_parent(rev.resolve(context))
    end
  end # Parent is equivalent to Ancestor(:rev, 1)

  Ancestor = Struct.new(:rev, :n) do
    def resolve(context)
      oid = rev.resolve(context)
      n.times { oid = context.commit_parent(oid) }
      oid
    end
  end

  INVALID_NAME = %r{
  ^\.
  | /\.
  | \.\.
  | /$
  | \.lock$
  | @\{
  | [\x00-\x20*:?\[\\^~\x7f]
  }x
  PARENT = /^(.+)\^$/
  ANCESTOR = /^(.+)~(\d+)$/
  HEAD = 'HEAD'
  REF_ALIASES = {
    '@' => HEAD
  }
  COMMIT = 'commit'
  InvalidObject = Class.new(StandardError)
  HintedError = Struct.new(:message, :hint)

  attr_reader :errors

  def initialize(repo, expression)
    @repo = repo
    @expr = expression
    @query = Revision.parse(@expr)
    @errors = []
  end

  def resolve(type = nil)
    oid = @query&.resolve(self)
    oid = nil if type and !load_typed_object(oid, type)
    return oid if oid

    raise InvalidObject, "Not a valid object name: '#{@expr}'."
  end

  def self.parse(revision)
    if match = PARENT.match(revision)
      rev = Revision.parse(match[1])
      rev ? Parent.new(rev) : nil
    elsif match = ANCESTOR.match(revision)
      rev = Revision.parse(match[1])
      rev ? Ancestor.new(rev, match[2].to_i) : nil
    elsif Revision.valid_ref?(revision)
      name = REF_ALIASES[revision] || revision
      Ref.new(name)
    end
  end

  def self.valid_ref?(revision)
    INVALID_NAME !~ revision
  end

  def commit_parent(oid)
    return nil unless oid

    commit = load_typed_object(oid, COMMIT)
    commit&.parent
  end

  def read_ref(name)
    oid = @repo.refs.read_ref(name)
    return oid if oid

    candidates = @repo.database.prefix_match(name)
    return candidates.first if candidates.size == 1

    # find all elements in `candidates` whose type is COMMIT. Return the first one if only one is found
    commit_candidates = candidates.select do |oid|
      object = load_object_if_type_matches(oid, COMMIT)
      !object.nil?
    end

    return commit_candidates.first if commit_candidates.size == 1

    log_ambiguous_sha1(name, candidates) if candidates.size > 1
    nil
  end

  private

  def load_object_if_type_matches(oid, type)
    object = @repo.database.load(oid)
    return unless object.type == type

    object
  end

  def load_typed_object(oid, type)
    return nil unless oid

    object = load_object_if_type_matches(oid, type)
    if object
      object
    else
      message = "object #{oid} is a #{object.type}, not a #{type}"
      @errors.push(HintedError.new(message, []))
      nil
    end
  end

  def log_ambiguous_sha1(name, candidates)
    objects = candidates.sort.map do |oid|
      object = @repo.database.load(oid)
      short = @repo.database.short_oid(object.oid)
      info = " #{short} #{object.type}"
      if object.type == 'commit'
        "#{info} #{object.author.short_date} - #{object.title_line}"
      else
        info
      end
    end
    message = "short SHA1 #{name} is ambiguous"
    hint = ['The candidates are:'] + objects
    @errors.push(HintedError.new(message, hint))
  end
end

require_relative '../revision'

module Command
  class Branch < Base
    def run
      create_branch
      exit 0
    end

    private

    def create_branch
      branch_name = @args[0]
      start_point = @args[1]
      if start_point
        revision = Revision.new(repo, start_point)
        start_oid = revision.resolve(Revision::COMMIT)
      else
        start_oid = repo.refs.read_head
      end
      repo.refs.create_branch(branch_name, start_oid)
    rescue Revision::InvalidObject => e
      revision.errors.each do |err|
        @stderr.puts "error: #{err.message}"
        err.hint.each { |line| @stderr.puts "hint: #{line}" }
      end
      @stderr.puts "fatal: #{e.message}"
      exit 128
    end
  end
end

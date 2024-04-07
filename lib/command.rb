require_relative './command/add'
require_relative './command/branch'
require_relative './command/checkout'
require_relative './command/cherry_pick'
require_relative './command/commit'
require_relative './command/diff'
require_relative './command/init'
require_relative './command/log'
require_relative './command/merge'
require_relative './command/revert'
require_relative './command/rm'
require_relative './command/stash'
require_relative './command/status'

module Command
  Unknown = Class.new(StandardError)
  COMMANDS = {
    'init' => Init,
    'add' => Add,
    'branch' => Branch,
    'checkout' => Checkout,
    'cherry-pick' => CherryPick,
    'commit' => Commit,
    'diff' => Diff,
    'log' => Log,
    'merge' => Merge,
    'revert' => Revert,
    'rm' => Rm,
    'stash' => Stash,
    'status' => Status
  }

  def self.execute(dir, env, argv, stdin, stdout, stderr)
    name = argv.first
    args = argv.drop(1)
    raise Unknown, "'#{name}' is not a jit command." unless COMMANDS.has_key?(name)

    command_class = COMMANDS[name]
    command = command_class.new(dir, env, args, stdin, stdout, stderr)
    command.execute
    command
  end
end

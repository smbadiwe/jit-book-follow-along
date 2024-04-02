require './lib/diff'

a = 'ABCABBA'.chars
b = 'CBABAC'.chars
edits = Diff.diff(a, b)
edits.each { |edit| puts edit }

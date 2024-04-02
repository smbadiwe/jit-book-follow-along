module Diff
  class Myers
    def self.diff(a, b)
      Myers.new(a, b).diff
    end

    def initialize(a, b)
      @a = a
      @b = b
    end

    def diff
      diff = []
      backtrack do |prev_x, prev_y, x, y|
        a_line = @a[prev_x] if prev_x < @a.size
        b_line = @b[prev_y] if prev_y < @b.size
        if x == prev_x
          diff.push(Edit.new(:ins, b_line))
        elsif y == prev_y
          diff.push(Edit.new(:del, a_line))
        else
          diff.push(Edit.new(:eql, a_line))
        end
      end
      diff.reverse
    end

    def shortest_edit
      n = @a.size
      m = @b.size
      max = n + m

      v = Array.new(2 * max + 1)
      v[1] = 0
      trace = []
      (0..max).step do |d|
        trace.push(v.clone)

        (-d..d).step(2) do |k|
          x = if k == -d or (k != d and v[k - 1] < v[k + 1])
                v[k + 1]
              else
                v[k - 1] + 1
              end
          y = x - k

          while x < n and y < m and @a[x] == @b[y]
            x += 1
            y += 1
          end

          v[k] = x

          return trace if x >= n and y >= m
        end
      end
    end

    def backtrack
      x = @a.size
      y = @b.size
      shortest_edit.each_with_index.reverse_each do |v, d|
        k = x - y
        prev_k = if k == -d or (k != d and v[k - 1] < v[k + 1])
                   k + 1
                 else
                   k - 1
                 end
        prev_x = v[prev_k]
        prev_y = prev_x - prev_k

        while x > prev_x and y > prev_y
          yield x - 1, y - 1, x, y
          x -= 1
          y -= 1
        end

        yield prev_x, prev_y, x, y if d > 0
        x = prev_x
        y = prev_y
      end
    end
  end
end

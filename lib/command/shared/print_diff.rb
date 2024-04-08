    DIFF_FORMATS = {
      context: :normal,
      meta: :bold,
      frag: :cyan,
      old: :red,
      new: :green
    }

    def diff_fmt(name, text)
      key = ['color', 'diff', name]
      style = repo.config.get(key)&.split(/ +/) || DIFF_FORMATS.fetch(name)
      fmt(style, text)
    end

      puts diff_fmt(:meta, string)
      puts diff_fmt(:frag, hunk.header)
      when :eql then puts diff_fmt(:context, text)
      when :ins then puts diff_fmt(:new, text)
      when :del then puts diff_fmt(:old, text)
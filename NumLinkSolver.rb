# encoding: utf-8
require 'forwardable'

# = NumberLink Solver Module
module NumberLink
  TRACE = true
  BREAK = 1000
  EMPTY = ''
  START_MARK = 'S'
  MID_MARK = 'M'
  END_MARK = 'E'
  CLOSE_MARK = '*'
  FILLER = ' . '
  FD1_MARK = ' o '
  UP_MARK = ' ^ '
  DOWN_MARK = ' v '
  LEFT_MARK = '<'
  RIGHT_MARK = '>'
  BLANK = '   '
  V_WALL = '|'
  H_WALL = '---'
  X_WALL = '+'

  NEIGHBOR_DIRECTIONS = {
    RIGHT_MARK => [+0, +1],
    DOWN_MARK  => [+1, +0],
    LEFT_MARK  => [+0, -1],
    UP_MARK    => [-1, +0]
  }

  AROUND_DIRECTIONS = [
    [+0, +1],
    [+1, +1],
    [+1, +0],
    [+1, -1],
    [+0, -1],
    [-1, -1],
    [-1, +0],
    [-1, +1]
  ]

  SPLIT_PATTERNS = [
    9, 10, 11, *17..19, *25..27,
    *33..47, *49..51, *57..59, 66,
    68, 70, *72..78, 82, 98, 100,
    102, 104, *105..108, 110, 114,
    122, 130, 132, 134, *136..140,
    142, *144..148, 150, *152..156,
    158, *160..180, 182, *184..188,
    190, 194, 196, 198, *200..204,
    206, 210, 226, 228, 230,
    *232..236, 238, 242, 250
  ]

  # = Debug utility methods
  module Debug
    def success(msg, *args)
      out("----- #{msg} -----", *args) if $DEBUG
      true
    end

    def error(msg, *args)
      out("----- #{msg} -----", *args) if $DEBUG
      false
    end

    def trace(msg, *args)
      out(msg, *args) if TRACE
    end

    def out(msg, *args)
      puts
      puts msg
      args.each { |arg| puts arg }
      puts
    end

    module_function :success, :error, :trace, :out
  end

  # = NumberLink problem definition
  class Definition < Struct.new(
    :sz,
    :link_tbl
  )
    def initialize
      super(0, {})
    end

    def size(value)
      self.sz = value
    end

    def link(link_name, *points)
      link_tbl[link_name] = points
    end
  end

  # = Information of each link or part of link
  class LinkSection < Struct.new(
    :name,
    :st,
    :ed,
    :has_next,
    :has_prev
  )
    def initialize(name, st, ed)
      super(name, st, ed, false, false)
    end

    def to_s
      "#{name}:#{st}-#{ed}"
    end
  end

  # = enumerates point
  class PointEnumerator
    extend Forwardable
    def_delegators :@e, :each, :any?

    def initialize(g, &blk)
      @e = Enumerator.new(&blk)
      @g = g
    end

    def select(&blk)
      @e = @e.select(&blk)
      self
    end

    def lazy
      @e = @e.lazy
      self
    end

    def inner
      select { |p| @g.inside?(p) }
    end

    def emptys
      select { |p| @g.empty_at?(p) }
    end
  end

  # = enumerates direction and point
  class DirEnumerator < PointEnumerator
    def inner
      select { |d, p| @g.inside?(p) }
    end

    def emptys
      select { |d, p| @g.empty_at?(p) }
    end
  end

  # = utility for grid calculation
  module GridCalc
    def inside?(p)
      p.all? { |x| x.between?(0, sz - 1) }
    end

    def all_points
      PointEnumerator.new(self) do |yielder|
        sz.times do |x|
          sz.times do |y|
            yielder.yield [x, y]
          end
        end
      end
    end

    def neighbors(p)
      PointEnumerator.new(self) do |yielder|
        NEIGHBOR_DIRECTIONS.each_value do |d|
          yielder.yield [p[0] + d[0], p[1] + d[1]]
        end
      end
    end

    def neighbor_dirs(p)
      DirEnumerator.new(self) do |yielder|
        NEIGHBOR_DIRECTIONS.each do |dir, d|
          yielder.yield dir, [p[0] + d[0], p[1] + d[1]]
        end
      end
    end

    def arounds(p)
      PointEnumerator.new(self) do |yielder|
        AROUND_DIRECTIONS.each do |d|
          yielder.yield [p[0] + d[0], p[1] + d[1]]
        end
      end
    end
  end

  # = status access methods
  module StatusHolder
    def [](p)
      stat_tbl[p]
    end

    def empty_at?(p)
      !stat_tbl.include?(p)
    end

    def open_at?(p)
      stat = stat_tbl[p]
      return false if stat == EMPTY
      return false if stat == FILLER
      return false if stat[-1] == CLOSE_MARK
      true
    end

    def closed_at?(p)
      stat_tbl[p][-1] == CLOSE_MARK
    end

    def open_stat_at(p, link_name, mark)
      stat_tbl[p] = sprintf('%2s%s', link_name, mark)
    end

    def close_stat_at(p, link_name = nil)
      link_name ||= stat_tbl[p][0, 2]
      stat_tbl[p] = sprintf('%2s%s' , link_name, CLOSE_MARK)
    end

    def fill_stat_at(p)
      stat_tbl[p] = FILLER
    end

    def set_direction(p, dir)
      case dir
      when RIGHT_MARK
        v_walls[p] = dir
      when LEFT_MARK
        v_walls[[p[0], p[1] - 1]] = dir
      when DOWN_MARK
        h_walls[p] = dir
      when UP_MARK
        h_walls[[p[0] - 1, p[1]]] = dir
      end
    end
  end

  # = link section access methods
  module LinkSectionHolder
    def current_sect
      sects.first
    end

    def add_sect(sec)
      last_sec = sects.last
      sects << sec
      if last_sec && last_sec.name == sec.name
        last_sec.has_next = true
        sec.has_prev = true
      end
    end

    def remove_sect(sec)
      sects.delete sec
    end
  end

  # = Forward-1 points access methods
  module Fd1PointsHolder
    def fd1_points
      fd1_tbl.keys
    end

    def add_fd1_point(p)
      fd1_tbl[p] = true
    end

    def remove_fd1_point(p)
      fd1_tbl.delete(p)
    end
  end

  # = link manipulation methods
  module LinkHandler
    def init_links(definition)
      self.sz = definition.sz
      definition.link_tbl.each do |name, pts|
        pts.each_cons(2) { |st, ed| add_sect(LinkSection.new(name, st, ed)) }
        open_link(pts.first, name, START_MARK)
        pts[1..-2].each { |p| open_link(p, name, MID_MARK) }
        open_link(pts.last, name, END_MARK)
      end
      connect_links
    end

    def open_link(p, stat, mark = ' ')
      open_stat_at(p, stat, mark)
      update_fd1_point(p)
    end

    def connect_links
      sects.clone.each { |sec| connect_link(sec) }
    end

    def connect_link(sec = nil)
      sec ||= current_sect
      diff = [sec.ed[0] - sec.st[0], sec.ed[1] - sec.st[1]]
      dir_mark = NEIGHBOR_DIRECTIONS.key(diff)
      return unless dir_mark
      close_stat_at(sec.st) unless sec.has_prev
      set_direction(sec.st, dir_mark)
      close_stat_at(sec.ed) unless sec.has_next
      remove_sect(sec)
      Debug.success("link #{sec} closed", self)
    end

    def move(from, to, link_name, dir)
      close_stat_at(from)
      set_direction(from, dir)
      open_link(to, link_name)
      current_sect.st = to
      connect_link
    end
  end

  # = Branch check
  module BranchChecker
    def chk_branch?(p)
      sec_name = current_sect.name
      closed_stat = sprintf('%2s%s', sec_name, CLOSE_MARK)
      br = neighbors(p).lazy.inner.any? do |nbor|
        self[nbor] == closed_stat
      end
      return Debug.error("#{p}: branch of '#{sec_name}'", self) if br
      true
    end
  end

  # = Partition check
  module PartitionChecker
    def chk_partition?
      g = deep_copy
      g.all_points.lazy.emptys.each do |p|
        open_ends = {}
        return false unless g.fill_partition(p, open_ends)
        sec_active = false
        sects.each do |sec|
          next unless open_ends.include?(sec.st)
          next unless open_ends.include?(sec.ed)
          sec_active = true
          g.remove_sect(sec)
        end
        return Debug.error("#{p}: dead partition", g) unless sec_active
      end
      return Debug.error("#{g.current_sect}: split", g) unless g.sects.empty?
      true
    end

    def fill_partition(p, open_ends)
      free_cnt = 0
      neighbors(p).inner.each do |nbor|
        next if closed_at?(nbor)
        free_cnt += 1
        open_at?(nbor) && open_ends[nbor] = true
      end
      return Debug.error("#{p}: dead end", self) if free_cnt <= 1
      fill_stat_at(p)
      neighbors(p).lazy.inner.emptys.each do |nbor|
        return false unless fill_partition(nbor, open_ends)
      end
      true
    end
  end

  # = Forward 1 check
  module Fd1Checker
    def update_fd1_point(p)
      remove_fd1_point(p)
      arounds(p).inner.emptys.each do |arnd|
        if split_at?(arnd)
          add_fd1_point(arnd)
        else
          remove_fd1_point(arnd)
        end
      end
    end

    def split_at?(p)
      pat = 0
      arounds(p).each.with_index do |arnd, i|
        flag = 1 << i
        next pat |= flag unless inside?(arnd)
        next pat |= flag unless empty_at?(arnd)
      end
      SPLIT_PATTERNS.include?(pat)
    end

    def chk_forward1?
      fd1_points.all? { |fd| chk_forward1_at?(fd) }
    end

    def chk_forward1_at?(fd)
      g = deep_copy
      g.close_stat_at(fd, '0')
      g.all_points.lazy.emptys.each do |p|
        open_ends = {}
        g.fill_partition_forward1(p, open_ends)
        return Debug.error("#{fd}: dead partition at #{p}", g) if open_ends.empty?
        sects.each do |sec|
          next unless open_ends.include?(sec.st)
          next unless open_ends.include?(sec.ed)
          g.remove_sect(sec)
        end
      end
      return Debug.error("#{fd}: multiple split #{g.sects * ','}", g) if g.sects.size > 1
      true
    end

    def fill_partition_forward1(p, open_ends)
      fill_stat_at(p)
      neighbors(p).inner.each do |nbor|
        open_ends[nbor] = true if open_at?(nbor)
        next unless empty_at?(nbor)
        fill_partition_forward1(nbor, open_ends)
      end
    end
  end

  # = Information of grid
  class Grid < Struct.new(
    :sz,
    :stat_tbl,
    :h_walls,
    :v_walls,
    :sects,
    :fd1_tbl
  )
    def initialize
      super(0, Hash.new(EMPTY), {}, {}, [], {})
    end

    def deep_copy
      Marshal.load(Marshal.dump(self))
    end

    def to_s
      stat_grid.zip(v_grid)
        .map { |row| row.transpose.flatten.tap(&:pop).join('') }
        .zip(h_grid.map { |row| row.join(X_WALL) })
        .flatten.tap(&:pop).join("\n")
    end

    def stat_grid
      Array.new(sz) { Array.new(sz, BLANK) }
        .tap { |g| fd1_points.each { |p| g[p[0]][p[1]] = FD1_MARK } }
        .tap do |g|
          stat_tbl.each { |p, stat| g[p[0]][p[1]] = sprintf('%3s', stat) }
        end
    end

    def v_grid
      Array.new(sz) { Array.new(sz, V_WALL) }
        .tap { |g| v_walls.each { |p, dir| g[p[0]][p[1]] = dir } }
    end

    def h_grid
      Array.new(sz) { Array.new(sz, H_WALL) }
        .tap { |g| h_walls.each { |p, dir| g[p[0]][p[1]] = dir } }
    end

    include GridCalc
    include StatusHolder
    include LinkSectionHolder
    include Fd1PointsHolder
    include LinkHandler
    include BranchChecker
    include PartitionChecker
    include Fd1Checker
  end

  # = NumberLink Solver
  class Solver < Struct.new(
    :definition,
    :start_time,
    :cnt_tbl
  )
    def initialize
      super(nil, nil, nil)
    end

    def load(code)
      self.definition = Definition.new
      definition.instance_eval(code)
    end

    def start
      self.start_time = Time.now
      self.cnt_tbl = {
        br: 0, al: 0, pt: 0, fd: 0, ok: 0,
      }
      grid = Grid.new
      grid.init_links(definition)
      print_grid(grid)
      solve(grid)
    end

    def solve(grid)
      add_cnt(:al)
      exit if chk_solved(grid)
      return add_cnt(:pt) unless grid.chk_partition?
      return add_cnt(:fd) unless grid.chk_forward1?
      add_cnt(:ok)
      show_progress(grid)
      go_next(grid)
    end

    def go_next(grid)
      sec = grid.current_sect
      from = sec.st
      grid.neighbor_dirs(from).lazy.inner.emptys.each do |dir, to|
        next add_cnt(:br) unless grid.chk_branch?(to)
        grid2 = grid.deep_copy
        grid2.move(from, to, sec.name, dir)
        solve(grid2)
      end
    end

    def chk_solved(grid)
      if grid.sects.empty?
        Debug.success('!!!!solved!!!!', grid)
        print_grid(grid)
        return true
      end
      false
    end

    def add_cnt(c)
      cnt_tbl[c] += 1
    end

    def show_progress(grid)
      return unless BREAK > 0
      print '.'
      print_grid(grid) if cnt_tbl[:ok] % BREAK == 0
    end

    def print_grid(grid)
      puts
      puts self
      puts grid
      puts
    end

    def to_s
      time = Time.now - start_time
      hour, minsec = time.divmod(60 * 60)
      min, sec = minsec.divmod(60)
      cnt_str = cnt_tbl.map { |k, v| "#{k}:#{v}" } * ', '
      sprintf("tm:%02d:%02d:%02d, #{cnt_str}", hour, min, sec)
    end
  end
end

if __FILE__ == $PROGRAM_NAME

  # require 'profile'
  # Profiler__.start_profile

  solver = NumberLink::Solver.new
  solver.load(File.read(ARGV.shift))
  solver.start

  # Profiler__.stop_profile
  # Profiler__.print_profile(STDOUT)

end

# encoding: utf-8

# = NumberLink Solver Module
module NumberLink
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

  module Debug
    def log(msg, *args)
      return unless $DEBUG
      puts
      puts "----- #{msg} -----"
      args.each { |arg| puts arg }
      puts
    end
    module_function :log
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

  # = utility for grid calculation
  module GridCalc
    def inside?(p)
      p.all? { |x| x.between?(0, sz - 1) }
    end

    def all_points
      Enumerator.new do |yielder|
        sz.times do |x|
          sz.times do |y|
            yielder.yield [x, y]
          end
        end
      end
    end

    def neighbors(point)
      Enumerator.new do |yielder|
        NEIGHBOR_DIRECTIONS.each do |mark, diff|
          yielder.yield mark, [point[0] + diff[0], point[1] + diff[1]]
        end
      end
    end

    def neighbors_inner(point)
      neighbors(point).select { |m, p| inside?(p) }
    end

    def arounds(point)
      Enumerator.new do |yielder|
        AROUND_DIRECTIONS.each do |diff|
          yielder.yield [point[0] + diff[0], point[1] + diff[1]]
        end
      end
    end

    def arounds_inner(point)
      arounds(point).select { |p| inside?(p) }
    end

  end

  # = status access methods
  module StatusHolder
    def [](point)
      stat_tbl[point]
    end

    def empty_at?(point)
      !stat_tbl.include?(point)
    end

    def open_at?(point)
      stat = stat_tbl[point]
      return false if stat == EMPTY
      return false if stat == FILLER
      return false if stat[-1] == CLOSE_MARK
      true
    end

    def closed_at?(point)
      stat_tbl[point][-1] == CLOSE_MARK
    end

    def open_stat_at(point, link_name, mark)
      stat_tbl[point] = sprintf('%2s%s', link_name, mark)
    end

    def close_stat_at(point, link_name = nil)
      link_name ||= stat_tbl[point][0, 2]
      stat_tbl[point] = sprintf('%2s%s' , link_name, CLOSE_MARK)
    end

    def fill_stat_at(point)
      stat_tbl[point] = FILLER
    end

    def set_direction(point, dir_mark)
      case dir_mark
      when RIGHT_MARK
        v_walls[point] = dir_mark
      when LEFT_MARK
        v_walls[[point[0], point[1] - 1]] = dir_mark
      when DOWN_MARK
        h_walls[point] = dir_mark
      when UP_MARK
        h_walls[[point[0] - 1, point[1]]] = dir_mark
      end
    end
  end

  # = link section access methods
  module LinkSectionHolder
    def current_section
      sections.first
    end

    def add_section(sec)
      last_sec = sections.last
      sections << sec
      if last_sec && last_sec.name == sec.name
        last_sec.has_next = true
        sec.has_prev = true
      end
    end

    def delete_section(sec)
      sections.delete sec
    end
  end

  # = Forward-1 points access methods
  module Fd1PointsHolder
    def fd1_points
      fd1_tbl.keys
    end

    def add_fd1_point(point)
      fd1_tbl[point] = true
    end

    def delete_fd1_point(point)
      fd1_tbl.delete point
    end
  end

  # = link manipulation methods
  module LinkHandler
    def init_stat(definition)
      self.sz = definition.sz
      definition.link_tbl.each do |link_name, points|
        points.each_cons(2) do |st, ed|
          add_section(LinkSection.new(link_name, st, ed))
        end
        open_stat(points.first, link_name, START_MARK)
        points[1..-2].each do |point|
          open_stat(point, link_name, MID_MARK)
        end
        open_stat(points.last, link_name, END_MARK)
      end
      close_connected_links
    end

    def open_stat(point, stat, mark = ' ')
      open_stat_at(point, stat, mark)
      update_fd1_point(point)
    end

    def close_connected_links
      sections.clone.each do |sec|
        close_connected_link(sec)
      end
    end

    def close_connected_link(sec = nil)
      sec ||= current_section
      diff = [sec.ed[0] - sec.st[0], sec.ed[1] - sec.st[1]]
      dir_mark = NEIGHBOR_DIRECTIONS.key(diff)
      return unless dir_mark
      close_stat_at(sec.st) unless sec.has_prev
      set_direction(sec.st, dir_mark)
      close_stat_at(sec.ed) unless sec.has_next
      delete_section(sec)
      Debug.log("link #{sec} closed", self)
    end

    def move(from, to, link_name, dir_mark)
      close_stat_at(from)
      set_direction(from, dir_mark)
      open_stat(to, link_name)
      current_section.st = to
      close_connected_link
    end
  end

  # = Branch check
  module BranchChecker
    def chk_branch?(point)
      sec_name = current_section
      closed_stat = sprintf('%2s%s', sec_name, CLOSE_MARK)
      neighbors_inner(point).each do |dir_mark, neighbor|
        if self[neighbor] == closed_stat
          Debug.log("branch of '#{sec_name}' at #{point}", self)
          return false
        end
      end
      true
    end
  end

  # = Partition check
  module PartitionChecker
    def chk_partition?
      grid2 = deep_copy
      all_points.each do |point|
        next unless grid2.empty_at?(point)
        # dead end found
        exit_points = {}
        return false unless grid2.fill_partition(point, exit_points)
        sec_active = false
        sections.each do |sec|
          next unless exit_points.include?(sec.st)
          next unless exit_points.include?(sec.ed)
          sec_active = true
          grid2.delete_section(sec)
        end
        # checks if the partition contains active link
        unless sec_active
          Debug.log("dead partition at #{point}", grid2)
          return false
        end
      end
      # checks if unreachable link exists
      unless grid2.sections.empty?
        Debug.log("split link #{grid2.current_section}", grid2)
        return false
      end
      true
    end

    def fill_partition(point, exit_points)
      free_cnt = 0
      neighbors_inner(point).each do |dir_mark, neighbor|
        next if closed_at?(neighbor)
        # count if not closed
        free_cnt += 1
        # save exit point
        open_at?(neighbor) && exit_points[neighbor] = true
      end
      # dead end found
      if free_cnt <= 1
        Debug.log("dead end at #{point}", self)
        return false
      end
      fill_stat_at(point)
      neighbors_inner(point).each do |dir_mark, neighbor|
        next unless empty_at?(neighbor)
        return false unless fill_partition(neighbor, exit_points)
      end
      true
    end
  end

  # = Forward 1 check
  module Fd1Checker
    def update_fd1_point(point)
      delete_fd1_point(point)
      arounds_inner(point).each do |around|
        next unless empty_at?(around)
        unless split_at?(around)
          delete_fd1_point(around)
          next
        end
        add_fd1_point(around)
      end
    end

    def split_at?(point)
      split_pat = 0
      arounds(point).each_with_index do |around, i|
        flag = 1 << i
        inside?(around) || split_pat |= flag && next
        empty_at?(around) || split_pat |= flag
      end
      return true if SPLIT_PATTERNS.include?(split_pat)
      false
    end

    def chk_forward1?
      fd1_points.all? { |point| chk_forward1_at?(point) }
    end

    def chk_forward1_at?(fd)
      grid2 = deep_copy
      grid2.close_stat_at(fd, '0')
      all_points.each do |point|
        next unless grid2.empty_at?(point)
        exit_points = {}
        grid2.fill_partition_forward1(point, exit_points)
        # puts "  forward : #{fd}, exit : #{exit_points}" if $DEBUG
        # check if exit point exists
        if exit_points.empty?
          Debug.log("dead partition by #{fd} at #{point}", grid2)
          return false
        end
        # remove reachable links
        sections.each do |sec|
          next unless exit_points.include?(sec.st)
          next unless exit_points.include?(sec.ed)
          grid2.delete_section(sec)
        end
      end
      # check if multiple split exists
      if grid2.sections.size > 1
        Debug.log("multiple split at #{fd} for #{grid2.sections * ','}", grid2)
        return false
      end
      true
    end

    def fill_partition_forward1(point, exit_points)
      fill_stat_at(point)
      neighbors_inner(point).each do |dir_mark, neighbor|
        # save exit points
        open_at?(neighbor) && exit_points[neighbor] = true
        next unless empty_at?(neighbor)
        fill_partition_forward1(neighbor, exit_points)
      end
    end
  end

  # = Information of grid
  class Grid < Struct.new(
    :sz,
    :stat_tbl,
    :h_walls,
    :v_walls,
    :sections,
    :fd1_tbl
  )
    include GridCalc
    include StatusHolder
    include LinkSectionHolder
    include Fd1PointsHolder
    include LinkHandler
    include BranchChecker
    include PartitionChecker
    include Fd1Checker

    def initialize
      super(0, Hash.new(EMPTY), {}, {}, [], {})
    end

    def deep_copy
      Marshal.load(Marshal.dump(self))
    end

    def to_s
      stat_grid = Array.new(sz) { Array.new(sz, BLANK) }
      v_grid = Array.new(sz) { Array.new(sz, V_WALL) }
      h_grid = Array.new(sz) { Array.new(sz, H_WALL) }

      fd1_points.each do |point|
        stat_grid[point[0]][point[1]] = FD1_MARK
      end

      stat_tbl.each do |point, stat|
        stat_grid[point[0]][point[1]] = sprintf('%3s', stat)
      end

      v_walls.each do |point, dir|
        v_grid[point[0]][point[1]] = dir
      end

      h_walls.each do |point, dir|
        h_grid[point[0]][point[1]] = dir
      end

      stat_grid
        .zip(v_grid)
        .map do |row|
          row
            .transpose
            .flatten
            .tap(&:pop)
            .join('')
        end
        .zip(
          h_grid
            .map do |row|
              row.join(X_WALL)
            end
        )
        .flatten
        .tap(&:pop)
        .join("\n")
    end
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
        br: 0,
        al: 0,
        pt: 0,
        fd: 0,
        ok: 0,
      }
      grid = Grid.new
      grid.init_stat(definition)
      print_grid(grid)
      solve(grid)
    end

    def solve(grid)
      cnt_tbl[:al] += 1

      if grid.sections.empty?
        Debug.log('!!!!solved!!!!', self, grid)
        print_grid(grid)
        exit
      end

      grid.chk_partition? || (cnt_tbl[:pt] += 1) && return
      grid.chk_forward1? || (cnt_tbl[:fd] += 1) && return

      cnt_tbl[:ok] += 1
      print_progress(grid)
      sec = grid.current_section
      point = sec.st

      grid.neighbors_inner(point).each do |dir_mark, point2|
        next unless grid.empty_at?(point2)
        grid.chk_branch?(point2) || (cnt_tbl[:br] += 1) && next
        grid2 = grid.deep_copy
        grid2.move(point, point2, sec.name, dir_mark)
        solve(grid2)
      end
    end

    def print_progress(grid)
      return unless BREAK > 0
      print '.'
      cnt_tbl[:ok] % BREAK == 0 && print_grid(grid)
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

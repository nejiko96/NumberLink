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

  # = NumberLink Problem
  class Problem < Struct.new(
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
  class LinkPart < Struct.new(
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
          next unless (x = point[0] + diff[0]).between?(0, sz - 1)
          next unless (y = point[1] + diff[1]).between?(0, sz - 1)
          yielder.yield mark, [x, y]
        end
      end
    end

    def arounds(point)
      Enumerator.new do |yielder|
        AROUND_DIRECTIONS.each do |diff|
          next unless (x = point[0] + diff[0]).between?(0, sz - 1)
          next unless (y = point[1] + diff[1]).between?(0, sz - 1)
          yielder.yield [x, y]
        end
      end
    end

    def arounds_include_outside(point)
      Enumerator.new do |yielder|
        AROUND_DIRECTIONS.each do |diff|
          yielder.yield [point[0] + diff[0], point[1] + diff[1]]
        end
      end
    end
  end

  # = Information of grid
  class Grid < Struct.new(
    :sz,
    :stat_tbl,
    :h_walls,
    :v_walls,
    :link_parts,
    :fd1_tbl
  )
    include GridCalc

    def initialize(size)
      super(size, Hash.new(EMPTY), {}, {}, [], {})
    end

    def deep_copy
      Marshal.load(Marshal.dump(self))
    end

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

    def current_link
      link_parts.first
    end

    def add_link_part(link_part)
      last_part = link_parts.last
      link_parts << link_part
      if last_part && last_part.name == link_part.name
        last_part.has_next = true
        link_part.has_prev = true
      end
    end

    def delete_link_part(link_part)
      link_parts.delete link_part
    end

    def fd1_points
      fd1_tbl.keys
    end

    def add_fd1_point(point)
      fd1_tbl[point] = true
    end

    def delete_fd1_point(point)
      fd1_tbl.delete point
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
    :problem,
    :start_time,
    :cnt_tbl
  )
    def initialize
      super(nil, nil, nil)
    end

    def load(code)
      self.problem = Problem.new
      problem.instance_eval(code)
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
      grid = Grid.new(problem.sz)
      init_grid(grid)
      print_grid(grid)
      solve(grid)
    end

    def init_grid(grid)
      problem.link_tbl.each do |link_name, points|
        points.each_cons(2) do |st, ed|
          grid.add_link_part(LinkPart.new(link_name, st, ed))
        end
        open_stat(grid, points.first, link_name, START_MARK)
        points[1..-2].each do |point|
          open_stat(grid, point, link_name, MID_MARK)
        end
        open_stat(grid, points.last, link_name, END_MARK)
      end
      close_connected_links(grid)
    end

    def open_stat(grid, point, stat, mark = ' ')
      grid.open_stat_at(point, stat, mark)
      update_fd1_point(grid, point)
    end

    def update_fd1_point(grid, point)
      grid.delete_fd1_point(point)
      grid.arounds(point).each do |around|
        next unless grid.empty_at?(around)
        # grid.delete_fd1_point(around)
        unless split_at?(grid, around)
          grid.delete_fd1_point(around)
          next
        end
        grid.add_fd1_point(around)
      end
    end

    def close_connected_links(grid)
      grid.link_parts.clone.each do |lp|
        close_connected_link(grid, lp)
      end
    end

    def close_connected_link(grid, lp = nil)
      lp ||= grid.current_link
      diff = [lp.ed[0] - lp.st[0], lp.ed[1] - lp.st[1]]
      dir_mark = NEIGHBOR_DIRECTIONS.key(diff)
      return unless dir_mark
      grid.close_stat_at(lp.st) unless lp.has_prev
      grid.set_direction(lp.st, dir_mark)
      grid.close_stat_at(lp.ed) unless lp.has_next
      grid.delete_link_part(lp)
      puts "\n----- link #{lp} closed -----" if $DEBUG
      print_grid(grid) if $DEBUG
    end

    def solve(grid)
      cnt_tbl[:al] += 1

      if grid.link_parts.empty?
        puts "\n----- !!!!solved!!!! -----" if $DEBUG
        print_grid grid
        exit
      end

      # puts "\nstat_tbl : #{grid.stat_tbl}" if $DEBUG
      # puts "link_parts : #{grid.link_parts}" if $DEBUG
      # puts "fd1_points : #{grid.fd1_points}" if $DEBUG

      unless chk_partition?(grid)
        cnt_tbl[:pt] += 1
        return
      end

      unless chk_forward1?(grid)
        cnt_tbl[:fd] += 1
        return
      end

      print_progress grid

      lp = grid.current_link
      point = lp.st

      grid.neighbors(point).each do |dir_mark, point2|

        next unless grid.empty_at?(point2)

        unless chk_branch?(grid, point2)
          cnt_tbl[:br] += 1
          next
        end

        grid2 = grid.deep_copy
        grid2.close_stat_at(point)
        grid2.set_direction(point, dir_mark)
        open_stat(grid2, point2, lp.name)
        grid2.current_link.st = point2
        close_connected_link(grid2)

        solve(grid2)
      end
    end

    def chk_branch?(grid, point)
      lp = grid.current_link
      closed_stat = sprintf('%2s%s', lp.name, CLOSE_MARK)
      grid.neighbors(point).each do |dir_mark, neighbor|
        if grid[neighbor] == closed_stat
          puts "\n----- branch of '#{lp.name}' at #{point} -----" if $DEBUG
          print_grid(grid) if $DEBUG
          return false
        end
      end
      true
    end

    def chk_partition?(grid)
      grid2 = grid.deep_copy
      grid.all_points.each do |point|
        next unless grid2.empty_at?(point)
        # dead end found
        exit_points = {}
        unless fill_partition(grid2, point, exit_points)
          return false
        end
        part_active = false
        grid.link_parts.each do |lp|
          next unless exit_points.include?(lp.st)
          next unless exit_points.include?(lp.ed)
          part_active = true
          grid2.delete_link_part(lp)
        end
        # puts "  fill : #{point}, exit : #{exit_points}, active : #{part_active}" if $DEBUG
        # checks if the partition contains active link
        unless part_active
          puts "\n----- dead partition at #{point} -----" if $DEBUG
          print_grid(grid2) if $DEBUG
          return false
        end
      end
      # checks if unreachable link exists
      unless grid2.link_parts.empty?
        puts "\n----- split link #{grid2.current_link} -----" if $DEBUG
        print_grid(grid2) if $DEBUG
        return false
      end
      true
    end

    def fill_partition(grid, point, exit_points)
      free_cnt = 0
      grid.neighbors(point).each do |dir_mark, neighbor|
        next if grid.closed_at?(neighbor)
        # count if not closed
        free_cnt += 1
        # save exit point
        grid.open_at?(neighbor) && exit_points[neighbor] = true
      end
      # dead end found
      if free_cnt <= 1
        puts "\n----- dead end at #{point} -----" if $DEBUG
        print_grid grid if $DEBUG
        return false
      end
      grid.fill_stat_at(point)
      grid.neighbors(point).each do |dir_mark, neighbor|
        next unless grid.empty_at?(neighbor)
        return false unless fill_partition(grid, neighbor, exit_points)
      end
      true
    end

    def chk_forward1?(grid)
      grid.fd1_points.each do |point|
        return false unless chk_forward1_at?(grid, point)
      end
      true
    end

    def split_at?(grid, point)
      split_pat = 0
      grid.arounds_include_outside(point).each_with_index do |around, i|
        flag = 1 << i
        unless around[0].between?(0, grid.size - 1)
          split_pat |= flag
          next
        end
        unless around[1].between?(0, grid.size - 1)
          split_pat |= flag
          next
        end
        grid.empty_at?(around) || split_pat |= flag
      end
      # puts "point : #{point}, split_pat : #{split_pat}=>has split" if $DEBUG
      # puts "point : #{point}, split_pat : #{split_pat}=>no split" if $DEBUG
      return true if SPLIT_PATTERNS.include?(split_pat)
      false
    end

    def chk_forward1_at?(grid, fd)
      grid2 = grid.deep_copy
      grid2.close_stat_at(fd, '0')
      grid.all_points.each do |point|
        next unless grid2.empty_at?(point)
        fill_partition_forward1(grid2, point, exit_points = {})
        # puts "  forward : #{fd}, exit : #{exit_points}" if $DEBUG
        # check if exit point exists
        if exit_points.empty?
          puts "\n----- dead partition by #{fd} at #{point} -----" if $DEBUG
          print_grid grid2 if $DEBUG
          return false
        end
        # remove reachable links
        grid.link_parts.each do |lp|
          next unless exit_points.include?(lp.st)
          next unless exit_points.include?(lp.ed)
          grid2.delete_link_part(lp)
        end
      end
      # check if multiple split exists
      if grid2.link_parts.size > 1
        puts "\n----- multiple split at #{fd} for #{grid2.link_parts * ','} -----" if $DEBUG
        print_grid grid2 if $DEBUG
        return false
      end

      true
    end

    def fill_partition_forward1(grid, point, exit_points)
      grid.fill_stat_at(point)
      grid.neighbors(point).each do |dir_mark, neighbor|
        # save exit points
        grid.open_at?(neighbor) && exit_points[neighbor] = true
        next unless grid.empty_at?(neighbor)
        fill_partition_forward1(grid, neighbor, exit_points)
      end
    end

    def print_progress(grid)
      if BREAK > 0
        print '.'
        cnt_tbl[:ok] += 1
        cnt_tbl[:ok] % BREAK > 0 || print_grid(grid)
      end
    end

    def print_grid(grid)
      time = Time.now - start_time
      time2 = time.divmod(60 * 60)
      time3 = time2[1].divmod(60)
      cnt_str = cnt_tbl.map { |k, v| "#{k}:#{v}" } * ', '
      puts sprintf(
        "\ntm:%02d:%02d:%02d, #{cnt_str}\n",
        time2[0], time3[0], time3[1]
      )
      puts grid
      puts
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

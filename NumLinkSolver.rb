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
    :link_defs
  )
    def initialize
      super(0, {})
    end

    def size(value)
      self.sz = value
    end

    def link(link_name, *points)
      link_defs[link_name] = points
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

    def start()
      self.start_time = Time.now
      self.cnt_tbl = {
        br: 0,
        al: 0,
        pt: 0,
        fd: 0,
        ok: 0,
      }
      status = NumLinkStatus.new(problem.sz)
      init_status(status)
      print_status(status)
      solve(status)
    end

    def init_status(status)
      problem.link_defs.each do |link_name, points|
        points.each_cons(2) do |st, ed|
          status.add_link_part(LinkPart.new(link_name, st, ed))
        end
        open_stat(status, points.first, link_name, START_MARK)
        points[1..-2].each do |point|
          open_stat(status, point, link_name, MID_MARK)
        end
        open_stat(status, points.last, link_name, END_MARK)
      end
      close_connected_links(status)
    end

    def open_stat(status, point, stat, mark = ' ')
      status.open_stat_at(point, stat, mark)
      update_fd1_point(status, point)
    end

    def update_fd1_point(status, point)
      status.delete_fd1_point(point)

      arounds(point).each do |around|

        next unless status.empty_at?(around)
        # status.delete_fd1_point(around)

        unless split_at?(status, around)
          status.delete_fd1_point(around)
          next
        end

        status.add_fd1_point(around)
      end
    end

    def close_connected_links(status)
      status.link_parts.clone.each do |lp|
        close_connected_link(status, lp)
      end
    end

    def close_connected_link(status, lp = nil)
      lp ||= status.current_link
      diff = [lp.ed[0] - lp.st[0], lp.ed[1] - lp.st[1]]
      dir_mark = NEIGHBOR_DIRECTIONS.key(diff)
      return unless dir_mark

      status.close_stat_at(lp.st) unless lp.has_prev
      status.set_direction(lp.st, dir_mark)
      status.close_stat_at(lp.ed) unless lp.has_next
      status.delete_link_part(lp)

      puts "\n----- link #{lp} closed -----" if $DEBUG
      print_status status if $DEBUG
    end

    def solve(status)
      cnt_tbl[:al] += 1

      if status.link_parts.empty?
        puts "\n----- !!!!solved!!!! -----" if $DEBUG
        print_status status
        exit
      end

      # puts "\nstat_tbl : #{status.stat_tbl}" if $DEBUG
      # puts "link_parts : #{status.link_parts}" if $DEBUG
      # puts "fd1_points : #{status.fd1_points}" if $DEBUG

      unless chk_partition?(status)
        cnt_tbl[:pt] += 1
        return
      end

      unless chk_forward1?(status)
        cnt_tbl[:fd] += 1
        return
      end

      print_progress status

      lp = status.current_link
      point = lp.st

      neighbors(point).each do |dir_mark, point2|

        next unless status.empty_at?(point2)

        unless chk_branch?(status, point2)
          cnt_tbl[:br] += 1
          next
        end

        status2 = status.deep_copy
        status2.close_stat_at(point)
        status2.set_direction(point, dir_mark)
        open_stat(status2, point2, lp.name)
        status2.current_link.st = point2
        close_connected_link(status2)

        solve(status2)
      end
    end

    def chk_branch?(status, point)
      lp = status.current_link
      closed_stat = sprintf('%2s%s', lp.name, CLOSE_MARK)

      neighbors(point).each do |dir_mark, neighbor|
        if status[neighbor] == closed_stat
          puts "\n----- branch of '#{lp.name}' at #{point} -----" if $DEBUG
          print_status status if $DEBUG
          return false
        end
      end
      true
    end

    def chk_partition?(status)
      status2 = status.deep_copy

      all_points.each do |point|

        next unless status2.empty_at?(point)

        # dead end found
        unless fill_partition(status2, point, exit_points = {})
          return false
        end

        part_active = false
        status.link_parts.each do |lp|
          next unless exit_points.include?(lp.st)
          next unless exit_points.include?(lp.ed)
          part_active = true
          status2.delete_link_part(lp)
        end

        # puts "  fill : #{point}, exit : #{exit_points}, active : #{part_active}" if $DEBUG

        # checks if the partition contains active link
        unless part_active
          puts "\n----- dead partition at #{point} -----" if $DEBUG
          print_status(status2) if $DEBUG
          return false
        end

      end

      # checks if unreachable link exists
      unless status2.link_parts.empty?
        puts "\n----- split link #{status2.current_link} -----" if $DEBUG
        print_status(status2) if $DEBUG
        return false
      end
      true
    end

    def fill_partition(status, point, exit_points)
      free_cnt = 0

      neighbors(point).each do |dir_mark, neighbor|
        next if status.closed_at?(neighbor)
        # count if not closed
        free_cnt += 1
        # save exit point
        status.open_at?(neighbor) && exit_points[neighbor] = true
      end

      # dead end found
      if free_cnt <= 1
        puts "\n----- dead end at #{point} -----" if $DEBUG
        print_status status if $DEBUG
        return false
      end

      status.fill_stat_at(point)

      neighbors(point).each do |dir_mark, neighbor|
        next unless status.empty_at?(neighbor)
        return false unless fill_partition(status, neighbor, exit_points)
      end
      true
    end

    def chk_forward1?(status)
      status.fd1_points.each do |point|
        return false unless chk_forward1_at?(status, point)
      end
      true
    end

    def split_at?(status, point)
      split_pat = 0

      AROUND_DIRECTIONS.each_with_index do |direction, i|
        flag = 1 << i

        x = point[0] + direction[0]
        unless x.between?(0, problem.sz - 1)
          split_pat |= flag
          next
        end

        y = point[1] + direction[1]
        unless y.between?(0, problem.sz - 1)
          split_pat |= flag
          next
        end

        status.empty_at?([x, y]) || split_pat |= flag
      end

      if SPLIT_PATTERNS.include?(split_pat)
        # puts "point : #{point}, split_pat : #{split_pat}=>has split" if $DEBUG
        return true
      end

      # puts "point : #{point}, split_pat : #{split_pat}=>no split" if $DEBUG
      false
    end

    def chk_forward1_at?(status, fd)
      status2 = status.deep_copy
      status2.close_stat_at(fd, '0')

      all_points.each do |point|

        next unless status2.empty_at?(point)

        fill_partition_forward1(status2, point, exit_points = {})

        # puts "  forward : #{fd}, exit : #{exit_points}" if $DEBUG

        # check if exit point exists
        if exit_points.empty?
          puts "\n----- dead partition by #{fd} at #{point} -----" if $DEBUG
          print_status status2 if $DEBUG
          return false
        end

        # remove reachable links
        status.link_parts.each do |lp|
          next unless exit_points.include?(lp.st)
          next unless exit_points.include?(lp.ed)
          status2.delete_link_part(lp)
        end
      end

      # check if multiple split exists
      if status2.link_parts.size > 1
        puts "\n----- multiple split at #{fd} for #{status2.link_parts * ','} -----" if $DEBUG
        print_status status2 if $DEBUG
        return false
      end

      true
    end

    def fill_partition_forward1(status, point, exit_points)
      status.fill_stat_at(point)

      neighbors(point).each do |dir_mark, neighbor|
        # save exit points
        status.open_at?(neighbor) && exit_points[neighbor] = true
        next unless status.empty_at?(neighbor)
        fill_partition_forward1(status, neighbor, exit_points)
      end
    end

    def print_progress(status)
      if BREAK > 0
        print '.'
        cnt_tbl[:ok] += 1
        cnt_tbl[:ok] % BREAK > 0 || print_status(status)
      end
    end

    def print_status(status)
      time = Time.now - start_time
      time2 = time.divmod(60 * 60)
      time3 = time2[1].divmod(60)
      cnt_str = cnt_tbl.map { |k, v| "#{k}:#{v}" } * ', '
      puts sprintf("\ntm:%02d:%02d:%02d, #{cnt_str}\n", time2[0], time3[0], time3[1])
      puts status
      puts
    end

    def all_points
      Enumerator.new do |yielder|
        problem.sz.times do |x|
          problem.sz.times do |y|
            yielder.yield [x, y]
          end
        end
      end
    end

    def neighbors(point)
      Enumerator.new do |yielder|
        NEIGHBOR_DIRECTIONS.each do |mark, direction|
          x = point[0] + direction[0]
          next unless x.between?(0, problem.sz - 1)
          y = point[1] + direction[1]
          next unless y.between?(0, problem.sz - 1)
          yielder.yield mark, [x, y]
        end
      end
    end

    def arounds(point)
      Enumerator.new do |yielder|
        AROUND_DIRECTIONS.each do |direction|
          x = point[0] + direction[0]
          next unless x.between?(0, problem.sz - 1)
          y = point[1] + direction[1]
          next unless y.between?(0, problem.sz - 1)
          yielder.yield [x, y]
        end
      end
    end
  end

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

  class NumLinkStatus < Struct.new(
    :size,
    :stat_tbl,
    :h_walls,
    :v_walls,
    :link_parts,
    :fd1_tbl
  )
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
      stat_grid = Array.new(size) { Array.new(size, BLANK) }
      v_grid = Array.new(size) { Array.new(size, V_WALL) }
      h_grid = Array.new(size) { Array.new(size, H_WALL) }

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

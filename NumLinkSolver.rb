class NumLinkSolver

  BREAK = 1000
  EMPTY = ""
  START_MARK = "S"
  MID_MARK = "M"
  END_MARK = "E"
  CLOSE_MARK = "*"
  FILLER = " . "
  FD1_MARK = " o "
  UP_MARK = " ^ "
  DOWN_MARK = " v "
  LEFT_MARK = "<"
  RIGHT_MARK = ">"
  BLANK = "   "    
  V_WALL = "|"    
  H_WALL = "---"
  X_WALL = "+"
  
  NEIGHBOR_DIRECTIONS = {
    RIGHT_MARK=>[ 0,  1],
    DOWN_MARK =>[ 1,  0],
    LEFT_MARK =>[ 0, -1],
    UP_MARK   =>[-1,  0]
  }

  AROUND_DIRECTIONS = [
    [ 0,  1],
    [ 1,  1],
    [ 1,  0],
    [ 1, -1],
    [ 0, -1],
    [-1, -1],
    [-1,  0],
    [-1,  1]
  ]

  SPLIT_PATTERNS = [
    9,10,11,*17..19,*25..27,
    *33..47,*49..51,*57..59,66,
    68,70,*72..78,82,98,100,
    102,104,*105..108,110,114,
    122,130,132,134,*136..140,
    142,*144..148,150,*152..156,
    158,*160..180,182,*184..188,
    190,194,196,198,*200..204,
    206,210,226,228,230,
    *232..236,238,242,250
  ]
  
  def initialize()
    @link_defs = Hash.new
  end
  
  def size(val)
    @size = val
  end
  
  def link(link_name, *points)
    @link_defs[link_name] = points
  end
  
  def start

    @start_time = Time.now
    @cnt_tbl = {
      :br => 0,
      :al => 0,
      :pt => 0,
      :fd => 0,
      :ok => 0,
    }
    status = NumLinkStatus.new(@size)
    init_status(status)
    print_status(status)
    solve(status)
  end
  
  def init_status(status)
    
    @link_defs.each { |link_name, points|
      
      points.each_cons(2) { |st, ed|
        status.add_link_part(LinkPart.new(link_name, st, ed))
      }
      
      open_stat(status, points.first, link_name, START_MARK)
      points[1..-2].each { |point|
        open_stat(status, point, link_name, MID_MARK)
      }
      open_stat(status, points.last, link_name, END_MARK)
    }
    
    close_connected_links(status)

  end
  
  def open_stat(status, point, stat, mark = " ")
      status.open_stat_at(point, stat, mark)
      update_fd1_point(status, point)
  end
  
  def update_fd1_point(status, point)
    
      status.delete_fd1_point(point)
      
      arounds(point).each { |around|
        
        next unless status.is_empty_at?(around)
        # status.delete_fd1_point(around)
  
        unless has_split_at?(status, around)
          status.delete_fd1_point(around)
          next
        end
      
        status.add_fd1_point(around)
      }
  end
  
  def close_connected_links(status)
    status.link_parts.clone.each { |lp|
      close_connected_link(status, lp)
    }
  end
  
  def close_connected_link(status, lp = nil)
    
    if lp == nil
      lp = status.current_link
    end

    diff = [lp.ed[0] - lp.st[0], lp.ed[1] - lp.st[1]]
    
    dir_mark = NEIGHBOR_DIRECTIONS.key(diff)
    return if dir_mark == nil
    
    status.close_stat_at(lp.st) unless lp.has_prev
    status.set_direction(lp.st, dir_mark)
    status.close_stat_at(lp.ed) unless lp.has_next
    status.delete_link_part(lp)
    
    puts "\n----- link #{lp} closed -----" if $DEBUG
    print_status status if $DEBUG
    
  end

  def solve(status)

    @cnt_tbl[:al] += 1
    
    if status.link_parts.empty?
      puts "\n----- !!!!solved!!!! -----" if $DEBUG
      print_status status
      exit
    end

    # puts "\nstat_tbl : #{status.stat_tbl}" if $DEBUG
    # puts "link_parts : #{status.link_parts}" if $DEBUG
    # puts "fd1_points : #{status.fd1_points}" if $DEBUG
    
    unless chk_partition?(status)
      @cnt_tbl[:pt] += 1
      return
    end
    
    unless chk_forward1?(status)
      @cnt_tbl[:fd] += 1
      return
    end

    print_progress status
 
    lp = status.current_link
    point = lp.st

    neighbors(point).each { |dir_mark, point2|
      
      next unless status.is_empty_at?(point2)
  
      unless chk_branch?(status, point2)
        @cnt_tbl[:br] += 1
        next
      end
  
      status2 = status.deep_copy
      status2.close_stat_at(point)
      status2.set_direction(point, dir_mark)
      open_stat(status2, point2, lp.name)
      status2.current_link.st = point2
      close_connected_link(status2)
      
      solve(status2)
    }

  end

  def chk_branch?(status, point)
    
    lp = status.current_link
    
    closed_stat = "%2s%s" % [lp.name, CLOSE_MARK]
    
    neighbors(point).each { |dir_mark, neighbor|   
      if status[neighbor] == closed_stat
        puts "\n----- branch of '#{lp.name}' at #{point} -----" if $DEBUG
        print_status status if $DEBUG
        return false
      end
    }
    return true
    
  end

  def chk_partition?(status)
    
    status2 = status.deep_copy
    
    all_points.each {|point|
      
      next unless status2.is_empty_at?(point)

      # 袋小路になってる
      unless fill_partition(status2, point, exit_points = {})
        return false
      end
      
      # 到達可能なリンクがあるかチェック
      part_active = false
      status.link_parts.each {|lp|
        next unless exit_points.include?(lp.st)
        next unless exit_points.include?(lp.ed)
        part_active = true
        status2.delete_link_part(lp)
      }
  
      # puts "  fill : #{point}, exit : #{exit_points}, active : #{part_active}" if $DEBUG

      # リンクが引けないシマ
      unless part_active
        puts "\n----- dead partition at #{point} -----" if $DEBUG
        print_status status2 if $DEBUG
        return false
      end
  
    }
  
    # 到達不可能なリンクがある場合
    if !status2.link_parts.empty?
      puts "\n----- split link #{status2.current_link} -----" if $DEBUG
      print_status status2 if $DEBUG
      return false
    end
    
    return true
    
  end

  def fill_partition(status, point, exit_points)
   
    free_cnt = 0;
    
    neighbors(point).each { |dir_mark, neighbor|
      
      next if status.is_closed_at?(neighbor)

      # 行き止まりでない壁をカウント
      free_cnt += 1

      # 未連結の箇所待避
      if status.is_open_at?(neighbor)
        exit_points[neighbor] = true
      end
    }
  
    # 袋小路になってる
    if free_cnt <= 1
      puts "\n----- dead end at #{point} -----" if $DEBUG
      print_status status if $DEBUG
      return false
    end
  
    status.fill_stat_at(point)
    
    neighbors(point).each { |dir_mark, neighbor|
      next unless status.is_empty_at?(neighbor)
      return false unless fill_partition(status, neighbor, exit_points)
    }
    return true
    
  end

  def chk_forward1?(status)

    status.fd1_points.each {|point|
      
      if !chk_forward1_at?(status, point)
        return false
      end
    }
    
    return true
    
  end
  
  def has_split_at?(status, point)
    
    split_pat = 0
    
    AROUND_DIRECTIONS.each_with_index {|direction, i|
      
      flag = 1 << i
      
      x = point[0] + direction[0]
      unless x.between?(0, @size-1)
        split_pat |= flag
        next
      end
      
      y = point[1] + direction[1]
      unless y.between?(0, @size-1)
        split_pat |= flag
        next
      end
      
      unless status.is_empty_at?([x, y])
        split_pat |= flag
      end
    }
    
    
    if SPLIT_PATTERNS.include?(split_pat)
      # puts "point : #{point}, split_pat : #{split_pat}=>has split" if $DEBUG
      return true
    end
    
    # puts "point : #{point}, split_pat : #{split_pat}=>no split" if $DEBUG
    return false
    
  end
  
  def chk_forward1_at?(status, fd)
    
    status2 = status.deep_copy
    status2.close_stat_at(fd, "0")
    
    all_points.each { |point|
      
      next unless status2.is_empty_at?(point)
      
      fill_partition_forward1(status2, point, exit_points = {})
      
      # puts "  forward : #{fd}, exit : #{exit_points}" if $DEBUG
      
      #出口がない場合
      if exit_points.empty?
        puts "\n----- dead partition by #{fd} at #{point} -----" if $DEBUG
        print_status status2 if $DEBUG
        return false
      end
      
      #到達可能なリンクを取り除く
      status.link_parts.each { |lp|
        next unless exit_points.include?(lp.st)
        next unless exit_points.include?(lp.ed)
        status2.delete_link_part(lp)
      }
    }

    # 到達不可能なリンクが複数ある場合
    if status2.link_parts.size > 1
      puts "\n----- multiple split at #{fd} for #{status2.link_parts * ','} -----" if $DEBUG
      print_status status2 if $DEBUG
      return false
    end
    
    return true
  end

  def fill_partition_forward1(status, point, exit_points)
     
    status.fill_stat_at(point)
    
    neighbors(point).each { |dir_mark, neighbor|
            
      # 未連結の箇所を待避
      if status.is_open_at?(neighbor)
        exit_points[neighbor] = true
      end

      next unless status.is_empty_at?(neighbor)
      
      fill_partition_forward1(status, neighbor, exit_points)
      
    }
    
  end
  
  def print_progress(status)
    if BREAK > 0
      print "."
      @cnt_tbl[:ok] += 1
      if @cnt_tbl[:ok] % BREAK == 0
        print_status status
      end
    end
  end

  def print_status(status)
    
    time = Time.now - @start_time
    time2 = time.divmod(60 * 60)
    time3 = time2[1].divmod(60)
    cnt_str = @cnt_tbl.map { |k, v| "#{k}:#{v}"} * ", "
    
    puts "\ntm:%02d:%02d:%02d, #{cnt_str}\n" \
          % [time2[0], time3[0], time3[1]]
    puts status
    puts
    
  end
  
  def all_points
    Enumerator.new { |yielder|
      @size.times { |x|
        @size.times { |y|
          yielder.yield [x, y]
        }
      }
    }
  end

  def neighbors(point)
    Enumerator.new { |yielder|
      NEIGHBOR_DIRECTIONS.each { |mark, direction|        
        x = point[0] + direction[0]
        next unless x.between?(0, @size-1)
        y = point[1] + direction[1]
        next unless y.between?(0, @size-1)
        yielder.yield mark, [x, y]
      }
    }
  end

  def arounds(point)
    Enumerator.new { |yielder|
      AROUND_DIRECTIONS.each { |direction|
        x = point[0] + direction[0]
        next unless x.between?(0, @size-1)
        y = point[1] + direction[1]
        next unless y.between?(0, @size-1)
        yielder.yield [x, y]
      }
    }
    
  end

  class LinkPart < Struct.new(:name, :st, :ed, :has_next, :has_prev)
    def initialize(name, st, ed)
      super(name, st, ed, false, false)
    end
    def to_s
      "#{name}:#{st}-#{ed}"
    end
  end

  class NumLinkStatus < Struct.new(:size, :stat_tbl, :h_walls, :v_walls, :link_parts, :fd1_tbl)
    
    def initialize(size)
      super(size, Hash.new(EMPTY), {}, {}, [], {})
    end
        
    def deep_copy()
      return Marshal.load(Marshal.dump(self))
    end

    def [](point)
      stat_tbl[point]
    end
    
    def is_empty_at?(point)
      !stat_tbl.include?(point)
    end

    def is_open_at?(point)
      stat = stat_tbl[point]
      return false if stat == EMPTY
      return false if stat == FILLER
      return false if stat[-1] == CLOSE_MARK
      return true
    end

    def is_closed_at?(point)
      stat_tbl[point][-1] == CLOSE_MARK
    end
      
    def open_stat_at(point, link_name, mark)
      stat_tbl[point] = "%2s%s" % [link_name, mark]
    end
    
    def close_stat_at(point, link_name = nil)
      if link_name == nil
        link_name = stat_tbl[point][0, 2]
      end
      stat_tbl[point] = "%2s%s" % [link_name, CLOSE_MARK]
    end
    
    def fill_stat_at(point)
      stat_tbl[point] = FILLER
    end
    
    def set_direction(point, dir_mark)
      case dir_mark
        when RIGHT_MARK
          v_walls[point] = dir_mark
        when LEFT_MARK
          v_walls[[point[0], point[1]-1]] = dir_mark
        when DOWN_MARK
          h_walls[point] = dir_mark
        when UP_MARK
          h_walls[[point[0]-1, point[1]]] = dir_mark
      end
    end
        
    def current_link
      link_parts.first
    end
            
    def add_link_part(link_part)
      last_part = link_parts.last
      link_parts << link_part
      if last_part && last_part.name == link_part.name
        last_part.has_next = true;
        link_part.has_prev = true;
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
      
      fd1_points.each { |point|
        stat_grid[point[0]][point[1]] = FD1_MARK
      }

      stat_tbl.each { |point, stat|
        stat_grid[point[0]][point[1]] = "%3s" % stat
      }

      v_walls.each { |point, dir|
        v_grid[point[0]][point[1]] = dir
      }

      h_walls.each { |point, dir|
        h_grid[point[0]][point[1]] = dir
      }

      stat_grid
        .zip(v_grid)
        .map {|row|
          row
            .transpose
            .flatten
            .tap(&:pop)
            .join("")
        }
        .zip(
          h_grid
            .map{ |row|
              row.join(X_WALL)
            }
        )
        .flatten
        .tap(&:pop)
        .join("\n")      
    end
  end
end

# require 'profile'
# Profiler__.start_profile

solver = NumLinkSolver.new()
solver.instance_eval(File.read(ARGV.shift))
solver.start

# Profiler__.stop_profile
# Profiler__.print_profile(STDOUT)


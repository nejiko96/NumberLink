class NumLinkSolver

  DEBUG = false
  BREAK = 1000
  EMPTY = ""
  FILLER = " . "
  FAKE_WALL = " 0*"
  START_MARK = "S"
  MID_MARK = "M"
  END_MARK = "E"
  CLOSE_MARK = "*"
  FD1_MARK = " o "
  UP_MARK = " ^ "
  DOWN_MARK = " v "
  LEFT_MARK = "<"
  RIGHT_MARK = ">"
  BLANK = "   "    
  V_WALL = "|"    
  H_WALL = "---"
  
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
    @all_points = [*0...@size].product([*0...@size])
  end
  
  def link(link_name, *points)
    @link_defs[link_name] = points
  end
  
  def solve
    @start_time = Time.now
    @all_cases = 0
    @branch_err = 0
    @partition_err = 0
    @forward_err = 0
    @ok_cases = 0
    
    status = NumLinkStatus.new
    
    init_status status
    close_connected_links status

    out_status status

    answer_gen status
  end
  
  def init_status(status)
    
    @link_defs.each { |link_name, points|
      
      (0..(points.length - 2)).each { |idx|
        status.add_link_part({:name=>link_name, :start=>points[idx], :end=>points[idx + 1]})
      }
      
      open_stat(status, points[0], link_name, START_MARK)
      (1..(points.length - 2)).each { |idx|
        open_stat(status, points[idx], link_name, MID_MARK)
      }
      open_stat(status, points.last, link_name, END_MARK)
    }
    
  end
  
  def open_stat(status, point, stat, mark = nil)
    
      status.set_stat(point, stat, mark)
      update_fd1_point(status, point)
      
  end
  
  def update_fd1_point(status, point)
    
      status.delete_fd1_point point
      
      arounds(point) { |around|
        
        if status.has_stat? around
          # status.delete_fd1_point around
          next
        end
  
        if !has_split_at?(status, around)
          status.delete_fd1_point around
          next
        end
      
        status.set_fd1_point around
      }
  end
  
  def close_connected_links(status)
    
    status.get_link_parts.clone.each { |lp|
      
      close_connected_link(status, lp)

    }

  end
  
  def close_connected_link(status, lp = nil)
    
    if lp == nil
      lp = status.get_link_part
    end

    diff = [lp[:end][0] - lp[:start][0], lp[:end][1] - lp[:start][1]]
    
    dir_mark = NEIGHBOR_DIRECTIONS.key(diff)
    if dir_mark == nil
      return
    end
    
    if !status.has_prev_link? lp
      status.close_stat lp[:start]
    end
    
    status.set_direction(lp[:start], dir_mark)
    
    if !status.has_next_link? lp
      status.close_stat lp[:end]
    end
    
    status.delete_link_part lp
    
    debug_print "\n----- link " + lp.to_s + " closed -----"
    debug_status status
    
  end

  def answer_gen(status)

    @all_cases += 1
    
    if status.link_parts_empty?
      debug_print "\n----- !!!!solved!!!! -----"
      out_status status
      exit
    end

    # debug_print "\nstats : " + status.get_stats.to_s
    # debug_print "link_parts : " + status.get_link_parts.to_s
    # debug_print "fd1_points : " + status.get_fd1_points.to_s
    
    if !chk_partition?(status)
      @partition_err += 1
      return
    end
    
    if !chk_forward1?(status)
      @forward_err += 1
      return
    end

    print_progress status
 
    lp = status.get_link_part
    point = lp[:start]

    neighbors(point) { |dir_mark, point2|
      
      if status.has_stat? point2
        next
      end
  
      if !chk_branch?(status, point2)
        @branch_err += 1
        next
      end
  
      status2 = status.deep_copy
      status2.close_stat(point)
      status2.set_direction(point, dir_mark)
      open_stat(status2, point2, lp[:name])
      status2.get_link_part[:start] = point2
      
      close_connected_link status2
      
      answer_gen status2
    }

  end

  def chk_branch?(status, point)
    
    lp = status.get_link_part
    
    closed_stat = "%2s%s" % [lp[:name], CLOSE_MARK]
    
    neighbors(point) { |dir_mark, neighbor|      
      if status.get_stat(neighbor) == closed_stat
        debug_print "\n----- branch of '" + lp[:name] + "' at " + point.to_s + " -----"
        debug_status status
        return false
      end
    }
    
    return true
    
  end

  def chk_partition?(status)
    
    status2 = status.deep_copy()
    
    @all_points.each {|point|
      
      if status2.has_stat? point
        next
      end

      # 袋小路になってる
      if !fill_partition(status2, point, (exit_points = Hash.new()))
        return false
      end
      
      # 到達可能なリンクがあるかチェック
      part_active = false
      status.get_link_parts.each {|lp|
        if !exit_points.include? lp[:start]
          next
        end
        if !exit_points.include? lp[:end]
          next
        end
        part_active = true
        status2.delete_link_part lp
      }
  
  
      # debug_print "  fill : " + point.to_s + ", exit : " + exit_points.to_s + ", active : " + part_active.to_s  

      # リンクが引けないシマ
      if !part_active
        debug_print "\n----- dead partition at " + point.to_s + " -----"
        debug_status status2
        return false
      end
  
    }
  
    # 到達不可能なリンクがある場合
    if !status2.link_parts_empty?
      debug_print "\n----- split link " + status2.get_link_part.to_s + " -----"
      debug_status status2
      return false
    end
    
    return true
    
  end

  def fill_partition(status, point, exit_points)
   
    free_cnt = 0;
    
    neighbors(point) { |dir_mark, neighbor|
      
      stat = status.get_stat(neighbor)
      
      if stat[2, 1] == CLOSE_MARK
        next
      end
      
      # 行き止まりでない壁をカウント
      free_cnt += 1

      # 未連結の箇所待避
      if stat[0, 2].to_i > 0
        exit_points[neighbor] = true
      end
        
    }
  
    #袋小路になってる
    if free_cnt <= 1
      debug_print "\n----- dead end at " + point.to_s + " -----"
      debug_status status
      return false
    end
  
    status.fill_stat(point)
    
    neighbors(point) { |dir_mark, neighbor|
      
      if status.has_stat? neighbor
        next
      end
      
      if !fill_partition(status, neighbor, exit_points)
        return false
      end
      
    }
    
    return true
    
  end

  def chk_forward1?(status)

    status.get_fd1_points.each {|point|
      
      if !chk_forward1_at?(status, point)
        return false
      end
    }
    
    return true
    
  end
  
  def has_split_at?(status, point)
    
    arounds = 0
    
    AROUND_DIRECTIONS.each_with_index {|direction, i|
      
      flag = 1 << i
      
      x = point[0] + direction[0]
      
      if x < 0 || x >= @size
        arounds |= flag
        next
      end
      
      y = point[1] + direction[1]
  
      if y < 0 || y >= @size
        arounds |= flag
        next
      end
      
      if status.has_stat?([x, y])
        arounds |= flag
      end
    }
    
    
    if SPLIT_PATTERNS.include? arounds
      # debug_print "point : " + point.to_s + ", arounds : " + arounds.to_s + "=>has split"
      return true
    end
    
    # debug_print "point : " + point.to_s + ", arounds : " + arounds.to_s + "=>no split"
    return false
    
  end
  
  def chk_forward1_at?(status, fd)
    
    status2 = status.deep_copy
    status2.set_stat(fd, "0", CLOSE_MARK)
    
    @all_points.each { |point|
      
      if status2.has_stat? point
        next
      end
      
      fill_partition_forward1(status2, point, exit_points = Hash.new)
      
      # debug_print "  forward : " + fd.to_s + ", exit : " + exit_points.to_s
      
      #出口がない場合
      if exit_points.empty?
        debug_print "\n----- dead partition by " + fd.to_s + " at " + point.to_s + " -----"
        debug_status status2
        return false
      end
      
      #到達可能なリンクを取り除く
      status.get_link_parts.each { |lp|
        if !exit_points.include? lp[:start]
          next
        end
        if !exit_points.include? lp[:end]
          next
        end
        status2.delete_link_part lp
      }
    }

    # 到達不可能なリンクが複数ある場合
    if status2.get_link_parts.length > 1
      debug_print "\n----- multiple split at " + fd.to_s + " for " + status2.get_link_parts.to_s  + " -----"
      debug_status status2
      return false
    end
    
    return true
    
  end

  def fill_partition_forward1(status, point, exit_points)
     
    status.fill_stat(point)
    
    neighbors(point) { |dir_mark, neighbor|
      
      stat = status.get_stat(neighbor)
      
      # 未連結の箇所を待避
      if stat[0, 2].to_i > 0 && stat[2, 1] != CLOSE_MARK
        exit_points[neighbor] = true
      end

      if status.has_stat?(neighbor)
        next
      end
      
      fill_partition_forward1(status, neighbor, exit_points)
      
    }
    
  end
  
  def print_progress(status)
    if BREAK > 0
      print "."
      @ok_cases += 1
      if @ok_cases % BREAK == 0
        out_status status
      end
    end
  end

  def out_status(status)
    
    time = Time.now - @start_time
    time2 = time.divmod(60 * 60)
    time3 = time2[1].divmod(60)
    
    printf "\ntm:%02d:%02d:%02d, br:%d, al:%d, pt:%d, fd:%d, ok:%d\n", \
            time2[0], time3[0], time3[1], @branch_err, @all_cases, @partition_err, @forward_err, @ok_cases
            
    status.print_in_grid @size
    puts
    
  end
  
  def neighbors(point)
    
    NEIGHBOR_DIRECTIONS.each { |mark, direction|
      
      x = point[0] + direction[0]
      
      if x < 0 || x >= @size
        next
      end
      
      y = point[1] + direction[1]
  
      if y < 0 || y >= @size
        next
      end
      
      yield mark, [x, y]
    }
    
  end

  def arounds(point)
    
    AROUND_DIRECTIONS.each { |direction|
      
      x = point[0] + direction[0]
      
      if x < 0 || x >= @size
        next
      end
      
      y = point[1] + direction[1]
  
      if y < 0 || y >= @size
        next
      end
      
      yield [x, y]
    }
    
  end
  
  def debug_print(s)
    if DEBUG
      puts s;
    end
  end
  
  def debug_status(status)
    if DEBUG
      out_status status
    end
  end

  class NumLinkStatus
    
    def initialize
      @stats = Hash.new(EMPTY)
      @h_walls = Hash.new
      @v_walls = Hash.new
      @link_parts = Array.new
      @next_links = Hash.new
      @prev_links = Hash.new
      @fd1_points = Hash.new
    end
        
    def deep_copy()
      return Marshal.load(Marshal.dump(self))
    end

    def get_stats
      @stats
    end

    def get_stat(point)
      @stats[point]
    end
    
    def has_stat?(point)
      @stats.include? point
    end

    def is_empty_stat?(point)
      !has_stat? point
    end
      
    def set_stat(point, stat, mark)
      if mark == nil
        @stats[point] = "%2s" % stat
      else
       @stats[point] = "%2s%s" % [stat, mark]
      end
    end
    
    def close_stat(point)
      @stats[point] = @stats[point][0, 2] + CLOSE_MARK
    end
    
    def fill_stat(point, stat = FILLER)
      @stats[point] = stat
    end
    
    def set_direction(point, dir_mark)
      if dir_mark == RIGHT_MARK
        @v_walls[point] = dir_mark
      elsif dir_mark == LEFT_MARK
        @v_walls[[point[0], point[1]-1]] = dir_mark
      elsif dir_mark == DOWN_MARK
        @h_walls[point] = dir_mark
      elsif dir_mark == UP_MARK
        @h_walls[[point[0]-1, point[1]]] = dir_mark
      end
    end
    
    def get_link_parts
      @link_parts
    end
    
    def get_link_part
      @link_parts[0]
    end
    
    def has_next_link?(link_part)
      @link_parts.include?(@next_links[link_part])
    end

    def has_prev_link?(link_part)
      @link_parts.include?(@prev_links[link_part])
    end
    
    def link_parts_empty?
      return @link_parts.empty?
    end
    
    def add_link_part(link_part)
      last_part = @link_parts.last
      @link_parts << link_part
      if last_part != nil && last_part[:name] == link_part[:name]
        @next_links[last_part] = link_part
        @prev_links[link_part] = last_part
      end
    end
    
    def delete_link_part(link_part)
      @link_parts.delete link_part
      @next_links.delete link_part
      @prev_links.delete link_part
    end
    
    def get_fd1_points
      @fd1_points.keys
    end
    
    def set_fd1_point(point)
      @fd1_points[point] = true
    end
    
    def delete_fd1_point(point)
      @fd1_points.delete point
    end

    def print_in_grid(size)
      
      stats_grid = Array.new(size) { Array.new(size, BLANK) }
      v_grid = Array.new(size) { Array.new(size, V_WALL) }
      h_grid = Array.new(size) { Array.new(size, H_WALL) }
      
      @fd1_points.keys.each { |point|
        stats_grid[point[0]][point[1]] = FD1_MARK
      }

      @stats.each { |point, stat|
        stats_grid[point[0]][point[1]] = "%3s" % stat
      }

      @v_walls.each { |point, dir|
        v_grid[point[0]][point[1]] = dir
      }

      @h_walls.each { |point, dir|
        h_grid[point[0]][point[1]] = dir
      }

      temp2 = stats_grid.zip(v_grid).map {|row|
        temp = row.transpose.flatten
        temp.pop
        temp.join("")
      }.zip(
        h_grid.map{ |row|
          row.join("+")
        }
      ).flatten
      temp2.pop
      
      puts temp2.join("\n")
      
    end
  
  end
end

# require 'profile'
# Profiler__.start_profile

solver = NumLinkSolver.new()
solver.instance_eval(File.read(ARGV.shift))
solver.solve

# Profiler__.stop_profile
# Profiler__.print_profile(STDOUT)


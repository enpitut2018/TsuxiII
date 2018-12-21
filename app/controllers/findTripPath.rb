require 'net/http'
require 'uri'
require 'json'

class TripPath

# attr_accessor :arrival, :departure
def initialize 
  @api_key = "AIzaSyDcvDBdNYh1_y30HsVYHy9hF6_O8OnN6oU"
end


def search(params)
  # 1. Google Map API で所要時間を取得する
  result = ask_GoogleMap_API(params)

  # 2. 出発地と目的地の場所をセットする
  @origin = get_origin_from(result)
  @destinations = get_destination_from(result)

  # 3. 所要時間行列を作る
  @time_matrix = generate_time_matrix(result,@destinations.length+1)

  # 4. パス検索のための前処理：配列を用意する
  initialize_arrays_for_search
  # 5. ユーザが指定した出発時刻や到着時刻などを設定する
  set_search_options(params)
  # 6. 指定した時間で回ることのできるパスを探す
  find_available_paths
  # 7. 各地点の到着・出発時刻を計算する
  calculate_schedule
  # 8. 実行可能なパスの中で一番いいパスを選択する
  select_best_path
end 

def ask_GoogleMap_API(params) 
  ori = []
  ori.push(params[:origin])
  ori.concat(params[:destinations].slice(0..params[:destinations].length-2))
  dst = params[:destinations]

  uri = URI.encode('https://maps.googleapis.com/maps/api/distancematrix/json?units=imperial&origins='+ori.join("|")+'&destinations='+dst.join("|")+'&mode=driving&key='+@api_key)
  json = Net::HTTP.get(URI.parse(uri))
  result = JSON.parse(json)
end

def get_origin_from(result)
  result["origin_addresses"][0]
end

def get_destination_from(result)
  result["destination_addresses"]
end

def generate_time_matrix(result,length)
  rows = result["rows"]

  time_matrix = Array.new(length).map{Array.new(length,0)}

  (0..length-2).each{ |i|
    (0..length-2).each{ |j|
      /^(\d*)\s*(hour|min)?s?\s*(\d*)(\smin)?.*$/ =~ rows[i]["elements"][j]["duration"]["text"]
      $2=="hour" ? time_matrix[i][j+1] = $1.to_i * 3600 : time_matrix[i][j+1] = $1.to_i * 60
      time_matrix[i][j+1] += $3.to_i * 60 unless $4.nil?
      time_matrix[j+1][i] = time_matrix[i][j+1]
    }
  }
  time_matrix
end

def initialize_arrays_for_search
  @paths = [*1..@destinations.length].permutation(@destinations.length).to_a
  @paths.map{ |p| p.unshift(0) }

  @arrival = Array.new(@paths.length).map{Array.new(@destinations.length+1,nil)}
  @stay = Array.new(@paths.length).map{Array.new(@destinations.length+1,3600)}
  @departure = Array.new(@paths.length).map{Array.new(@destinations.length+1,nil)}
  @available = Array.new(@paths.length,true)
  @scores = Array.new(@paths.length,0)
end


def find_available_paths
  @paths.each_with_index { |path,i|
    path.each_with_index { |point,j|

      next if j==0
      if @arrival[i][j].nil?
        unless @departure[i][j-1].nil?
          @arrival[i][j] = @departure[i][j-1]+@time_matrix[@paths[i][j-1]][@paths[i][j]]
          @departure[i][j] = @arrival[i][j]+@stay[i][j]
        end
      else
        @departure[i][j] = @arrival[i][j]+@stay[i][j]
      end

      if @departure[i][j-1].nil?
        @available[i] = true
      elsif @departure[i][j-1]+@time_matrix[@paths[i][j-1]][@paths[i][j]]<=@arrival[i][j]
        @available[i] = true
      else
        @available[i] = false
        break
      end
    } 
  }
end

def set_search_options(params)
  @paths.each_with_index { |path,i|
    path.each_with_index { |point,j|
      options = params[:options][point]
      @arrival[i][j] = options[:arrive] unless options[:arrive].nil?
      @departure[i][j] = options[:depart] unless options[:depart].nil?
      @stay[i][j] = options[:stay].to_i*60 unless options[:stay].nil?
    }
  }
end

def calculate_schedule
  @available.each_with_index{ |av,i|
    next if av==false
    @arrival.each_with_index.reverse_each{ |ar,j|
      break if ar.nil?
      if j>0 || @departure[i][j-1].nil?
        @departure[i][j-1] = @arrival[i][j]-@time_matrix[@paths[i][j-1]][@paths[i][j]]
        @arrival[i][j-1] = @departure[i][j-1]-@stay[i][j-1] if j>1
      end
    }
  }
end

def select_best_path
  return -1 if @available.all?{|av| av.nil?}
  best_path = 0
  if @arrival.all?{|ar| ar.nil?}
    score_function = lambda {|i,j|
      @time_matrix[@paths[i][j-1]][@paths[i][i]]
    }
  else
    score_function = lambda {|i,j|
      #@arrival[i][j]-(@departure[i][j-1]+@time_matrix[@paths[i][j-1]][@paths[i][j]])
      j==@paths.length-1 ? @arrival[i][j].to_i : 0
    }
  end
  @paths.each_with_index{|path,i|
    puts @available[i]
    break if @available[i]==false
    path.each_with_index{|point,j|
      next if j==0
      @scores[i] += score_function.call(i,j)
    }
    puts "["+i.to_s+"] score"+@scores[i].to_s
    best_path = i if @scores[i]<=@scores[best_path]
  }
  best_path
end

def print_best_schedule(best_path)
  if best_path==-1
      puts "条件に合うルートはありませんでした"
      return
  end
  puts "出発地："+@origin
  puts "　出発："+@departure[best_path][0].strftime("%H:%M")
  puts "... "
  @paths[best_path].each_with_index{|point,j|
    next if j==0
    if j == @paths.length
      puts "地点："+@destinations[point-1]
      puts "　到着： "+@arrival[best_path][j].strftime("%H:%M")
      puts "　出発： "+@departure[best_path][j].strftime("%H:%M")
      break
    end

    puts "地点："+@destinations[point-1]
    puts "　到着： "+@arrival[best_path][j].strftime("%H:%M")
    puts "　出発： "+@departure[best_path][j].strftime("%H:%M")
    puts " ... "
  }
end

end

trippath = TripPath.new
params = { :origin => "Tsukuba", :destinations => ["Moriya","Tokyo"],
           :options => [{:depart=>Time.local(2018,12,19,11,10)},
                        {:arrive=>Time.local(2018,12,19,15,0),:stay=>60},
                        {:arrive=>nil,:stay=>nil}]
       }
best_path = trippath.search(params)
puts best_path
trippath.print_best_schedule(best_path)
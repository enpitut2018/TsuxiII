class DestinationFormController < ApplicationController
  require 'net/https'
  require 'uri'
  require 'json'

  def new
  end

  def help
  end

  # 謎の文追加(https://qiita.com/ayacai115/items/ec7a621ec73692065d7aの、ActionController::InvalidAuthenticityTokenの対処法参照)
  protect_from_forgery except: :create # createアクションを除外

  def create

    @dev = 0
    @dev2 = 0
    @dev3 = 0
    @api_key = ENV["API_KEY"]

    unless params[:origin].present?
      params[:origin] = "つくば駅"
    end
    
    params[:destinations].each{ |n|
      unless n.present?
        n = nil
      end
    }

    params[:options].each{ |n|
      unless n[:depart].nil?
        if n[:depart].empty?
          n[:depart] = nil
        else
          /:/ =~ n[:depart]
          n[:depart] = Time.local(2018,12,19,$`,$')
        end
      end

      if n[:arrive].empty?
        n[:arrive] = nil
      else
        /:/ =~ n[:arrive]
        n[:arrive] = Time.local(2018,12,19,$`,$')
      end

      if n[:stay].empty?
        n[:stay] = nil
      else
        n[:stay] = n[:stay].to_i * 60
      end
    }


    # public_class_method :new
    # attr_accessor :arrival, :departure
    # paramsの形を定義
    # params = { :origin => "Tsukuba", :destinations => ["Moriya","Tokyo","Saitama","静岡駅","熱海駅","栃木駅","新潟駅","東京ディズニーシー"],
    #           :options => [{:depart=>Time.local(2018,12,19,11,10)},
    #                         {:arrive=>nil,:stay=>nil},
    #                         {:arrive=>nil,:stay=>nil},
    #                         {:arrive=>nil,:stay=>nil},
    #                         {:arrive=>nil,:stay=>nil},
    #                         {:arrive=>nil,:stay=>nil},
    #                         {:arrive=>nil,:stay=>nil},
    #                         {:arrive=>nil,:stay=>nil},
    #                         {:arrive=>nil,:stay=>nil}
    #                       ]
    #           }
    # params = { :origin => "Tsukuba", :destinations => ["静岡駅","熱海駅","栃木駅","東京ディズニーシー"],
    #           :options => [{:depart=>nil},
    #                         {:arrive=>nil,:stay=>nil},
    #                         {:arrive=>nil,:stay=>nil},
    #                         {:arrive=>nil,:stay=>nil},
    #                         {:arrive=>nil,:stay=>nil}
    #                       ]
    #           }

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
      # 不可能なパスの@scores[i]=0にするために
      @scores = Array.new(@paths.length,0)
    end


    def find_available_paths
      @paths.each_with_index { |path,i|
        path.each_with_index { |point,j|

          next if j==0
          if @arrival[i][j].nil?
            unless @departure[i][j-1].nil?
              @arrival[i][j] = @departure[i][j-1]+@time_matrix[@paths[i][j-1]][@paths[i][j]]
              @departure[i][j] = @arrival[i][j]
              # stay[i][j]がない時のために分けて考える(不要:デフォで1時間)
              @departure[i][j] += @stay[i][j] unless @stay[i][j].nil?
            end
          else
            @departure[i][j] = @arrival[i][j]
            # stay[i][j]がない時のために分けて考える(不要:デフォで1時間)
            @departure[i][j] += @stay[i][j] unless @stay[i][j].nil?
          end

          if @departure[i][j-1].nil?
            @available[i] = true
          elsif @departure[i][j-1]+@time_matrix[@paths[i][j-1]][@paths[i][j]] <= @arrival[i][j]
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
        # 1231修正(時間指定が全くない場合のために)
        next if @arrival[i].all?{|ar| ar==nil}
        @arrival[i].each_with_index.reverse_each{ |ar,j|
          @dev2 = ar
          # 重要!!!!!!1231でバグ発生場所()!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
          # 原因=配列のループを回して、その次の要素に変更を加えた場合でも、arの値は更新されず、arrival[i][j-1]
          # しか反映されていないため、arにnil判定を加えると、前回に更新していてもループがうまく回らない
          # これは、次のループ要素に対する変更を加えていることで起きる
          # next if ar==nil
          # if j>0 || @departure[i][j-1].nil?
          # 1221時点で、バグが発生していたところ
          # unless ar==nil~endは不要→どこか1地点でも指定があれば、その地点から最後までの到着、出発は決まり、
          # 逆順からのループを用いる場合は考慮する必要がなくなる
            if j>0 and @departure[i][j-1].nil?
              @dev = 2*j
              @departure[i][j-1] = @arrival[i][j]-@time_matrix[@paths[i][j-1]][@paths[i][j]]
              @dev3 = @departure[i][j-1]
              @arrival[i][j-1] = @departure[i][j-1]-@stay[i][j-1] if j>0
            end
        }
      }
    end

    def select_best_path
      # av.nil?から、av==falseへ修正(もともとnilは入れていない問題解決)
      return -1 if @available.all?{|av| av==false}
      best_path = 0
      if @arrival.all?{|ar| ar.all?{|a| a.nil?}}
    # if @arrival.all?{|ar| ar.nil?}
        score_function = lambda {|i,j|
          @time_matrix[@paths[i][j-1]][@paths[i][j]]
        }
      else
        score_function = lambda {|i,j|
          # @arrival[i][j]-(@departure[i][j-1]+@time_matrix[@paths[i][j-1]][@paths[i][j]])
          # 多分先生のミス
          # j==@paths.length-1 ? @arrival[i][j].to_i : 0
          # @destinations+originの数=@destinations.length-1+1(origin)=@destinations.length
          unless j == @destinations.length
            return 0
          else
            return @arrival[i][j].to_i
          end
        }
      end
      @paths.each_with_index{|path,i|
        puts @available[i]

        # break→nextに修正(全てのスコアが0の問題解決)

        next if @available[i]==false
        path.each_with_index{|point,j|
          next if j==0
          @scores[i] += score_function.call(i,j)
        }
        puts "["+i.to_s+"] score"+@scores[i].to_s
        best_path = i if @scores[i]<=@scores[best_path]
      }
      best_path
    end

    # 配列の初期化
    @routes = Array.new()


    # 出力結果を、1行の文字列として作成すると同時に、application.html.erb内の<script>内で、
    # 地図表示のそれぞれの場所を記録した@routesを作成する為のメソッドを定義
    def stringer_best_schedule(best_path)
      stringer = ""
      if best_path==-1
          stringer += "<h2>条件に合うルートはありませんでした</h2><br>"
          return stringer
      end

      stringer +=  "出発地：" + @origin + "<br>"

      # 行く順序に並べ替える
      @routes.push(@origin)
      # 時間指定が全くない場合の記述1
      unless @departure.all?{|de| de.all?{|d| d.nil?}}
        stringer += "　出発：" + @departure[best_path][0].strftime("%H:%M")  + "<br>"
        stringer += "↓" + "<br>"
      else
        stringer += "<br>"
      end

      @paths[best_path].each_with_index{|point,j|
        next if j==0
        # @destinations+originの数=@destinations.length-1+1(origin)=@destinations.length
        stopindex = @destinations.length
        if j == stopindex
          stringer += "到着地点：" + @destinations[point-1] + "<br>"

          # 行く順序に並べ替える
          @routes.push(@destinations[point-1])
          # 時間指定が全くない場合の記述2
          unless @arrival.all?{|ar| ar.all?{|a| a.nil?}}
            stringer += "　到着： " + @arrival[best_path][j].strftime("%H:%M") + "<br>"
          else
            stringer += "<br>"
          end
            return stringer
        end

        stringer += "地点：" + @destinations[point-1] + "<br>"

        # 行く順序に並べ替える
        @routes.push(@destinations[point-1])

        # 時間指定が全くない場合の記述3
        unless @departure.all?{|de| de.all?{|d| d.nil?}} or @arrival.all?{|ar| ar.all?{|a| a.nil?}}
          stringer += "　到着： " + @arrival[best_path][j].strftime("%H:%M") + "<br>"
          stringer += "　出発： " + @departure[best_path][j].strftime("%H:%M") + "<br>"
          stringer += "↓" + "<br>"
        else
          stringer += "<br>"
        end
      }
      return stringer
    end

    @best_path = search(params)
    @string = stringer_best_schedule(@best_path)

    if @best_path == -1
      @mapnotview = 0
    end

    # @trippath.print_best_schedule(@best_path)
  end
  
end
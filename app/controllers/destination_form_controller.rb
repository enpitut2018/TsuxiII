class DestinationFormController < ApplicationController
  require 'net/https'
  require 'uri'
  require 'json'

  def new
  end

  def create
    @origin = params[:origin]
    @destination_1 = params[:destination_1]
    @destination_2 = params[:destination_2]
    @hour = params[:hour]
    @minute = params[:minute]
    
    @c_hour = params[:c_hour]
    @c_minute = params[:c_minute]


    @keiyu_array = [@destination_1, @destination_2] # 経由地
    @sk_res = []                                  # 出発地から経由地のjson(s:start, k:keiyu)
    kk_res = []                                   # 経由地間のjson
    sk_keisan =[]                                 # 出発地から経由地の途中計算

    # スタートからそれぞれの経由地の時間を取得する
    [@destination_1, @destination_2].each do |d|
      uri = URI.encode('https://maps.googleapis.com/maps/api/distancematrix/json?units=imperial&origins='+@origin+'&destinations='+d+'&mode=driving&key='+ENV['API_KEY'])
      json = Net::HTTP.get(URI.parse(uri))
      @sk_res.push(JSON.parse(json))
    end

    # 経由地間の時間を取得する
    uri2 = URI.encode('https://maps.googleapis.com/maps/api/distancematrix/json?units=imperial&origins='+@destination_1+'&destinations='+@destination_2+'&mode=driving&key='+ENV['API_KEY'])
    json = Net::HTTP.get(URI.parse(uri2))
    kk_res = JSON.parse(json)

    @sk_res.each do |d|
      time = d['rows'][0]['elements'][0]['duration']['text']
      if time =~ /\shours|\shour/
          hour = $`
          if time =~ /\shours\s(.+)\smins|\shours\s(.+)\smin|\shour\s(.+)\smins|\shour\s(.+)\smin/
              time_new = (hour.to_s + '.' + $+.to_s).to_f
              sk_keisan.push(time_new)
          end
      elsif time =~ /\smins|\smin/
          time_new = ("0." + $`.to_s).to_f
          sk_keisan.push(time_new)
      end
  
    end
    
    # {経由地 => 出発地から経由地の途中計算} #値でsort
    hash = Hash[@keiyu_array.zip sk_keisan]
    sk_hash = Hash[hash.sort_by{ |_, v| v }]

    @near1 = sk_hash.keys[0]
    @near2 = sk_hash.keys[1]

    # {出発地から経由地のjson => 出発地から経由地の途中計算} #値でsort
    hash2 = Hash[@sk_res.zip sk_keisan]
    sk_hash_res = Hash[hash2.sort_by{ |_, v| v }]

    # スタートから近い経由地までの時間
    @sk_time = sk_hash_res.keys[0]['rows'][0]['elements'][0]['duration']['text']
    # 近い経由地から経由地までの時間
    @kk_time = kk_res['rows'][0]['elements'][0]['duration']['text']


    # ------------ s(スタート)からk(経由地1)までの時間演算---------------

    # start→viaの時間の初期設定(by t:1109)
    @sk_hour = @hour.to_i
    @sk_minute = @minute.to_i

    if @sk_time =~ /\shours|\shour/
      @sk_hour = $`.to_i + @sk_hour
      if @sk_time =~ /\shours\s(.+)\smins|\shours\s(.+)\smin|\shour\s(.+)\smins|\shour\s(.+)\smin/
        @sk_minute = $+.to_i + @sk_minute
      end
    elsif @sk_time =~ /\smins|\smin/
      @sk_minute = $`.to_i + @sk_minute
    end

    # 分が60を越える時の設定(by t:1109)
    if @sk_minute >= 60
      @sk_hour += 1
      @sk_minute -= 60
    end

    # 時間が24時を回る時の設定(by t:1109)
    if @sk_hour >= 24
      @sk_hour -= 24
    end

    # # 0-9分以内の場合の分表示の設定(by t:1109)
    # if @sk_minute < 10
    #   @sk_minute = "0" + @sk_minute.to_s
    # end
    
    # via→goalの時間の初期設定(by t:1109)
    @skk_h = @sk_hour.to_i
    @skk_m = @sk_minute.to_i

    if @kk_time =~ /\shours|\shour/
      @skk_h = @skk_h + $`.to_i
      if @kk_time =~ /\shours\s(.+)\smins|\shours\s(.+)\smin|\shour\s(.+)\smins|\shour\s(.+)\smin/
        @skk_m = @skk_m + $+.to_i
      end
    elsif @kk_time =~ /\smins|\smin/
      @skk_m = $`.to_i + @skk_m
    end 

    # 分が60を越える時の設定(by t:1109)
    if @skk_m >= 60
      @skk_h += 1
      @skk_m -= 60
    end

    # 時間が24時を回る時の設定(by t:1109)
    if @skk_h >= 24
      @skk_h -= 24
    end


    # ---------------- 時間指定された時の計算 ------------------------
    @dif_hour = @c_hour.to_i - @hour.to_i       # 指定時間と出発時間の差分(h)
    @dif_minute = @c_minute.to_i - @minute.to_i # 指定時間と出発時間の差分(m)
    @dif_time = (@dif_hour.to_s + "." + @dif_minute.to_s).to_f # 後の比較用

    # 変数定義&初期化
    @sd1hour = 0    #s→d1の差分(h)
    @sd1minute = 0  #s→d1の差分(m)
    @sd2time = @sk_res[1]['rows'][0]['elements'][0]['duration']['text']
    @sd2hour = 0    #s→d2の差分(h)
    @sd2minute = 0  #s→d2の差分(m)
    @sd1d2hour = 0  #s→d1→d2の差分(h)
    @sd1d2minute　= 0  #s→d1→d2の差分(m)
    @sd2d1hour　= 0    #s→d2→d1の差分(h)
    @sd2d1minute = 0   #s→d2→d1の差分(m)
    @order_time = 0    #正規ルート(近い順)で行った時の時間(小数)
    @reverse_time = 0  #非正規ルートで行った時の時間(小数)
    @orderz = 0   #@order_time - @dif_timeの絶対値
    @reversez = 0  #reverse_time - @dif_timeの絶対値

    # 時間指定した場所が出発地に近い時 
    if @destination_1 == @near1
      @sd1hour = @sk_hour - @hour.to_i
      @sd1minute = @sk_minute - @minute.to_i

      if @sd2time =~ /\shours|\shour/
        @sd2hour = $`.to_i
        if @sd2time =~ /\shours\s(.+)\smins|\shours\s(.+)\smin|\shour\s(.+)\smins|\shour\s(.+)\smin/
          @sd2minute = $+.to_i
        end
      elsif @sd2time =~ /\smins|\smin/
        @sd2minute = $`.to_i
      end

      if @kk_time =~ /\shours|\shour/
        @sd2d1hour = @sd2hour + $`.to_i
        if @kk_time =~ /\shours\s(.+)\smins|\shours\s(.+)\smin|\shour\s(.+)\smins|\shour\s(.+)\smin/
          @sd2d1minute = @sd2minute + $+.to_i
        end
      elsif @kk_time =~ /\smins|\smin/
        @sd2d1minute = $`.to_i + @sd2minute
      end
      if @sd2d1minute >= 60
        @sd2d1hour = @sd2d1hour.to_i + 1
        @sd2d1minute = @sd2d1minute - 60
      end 
      if @sd2d1hour.to_i >= 24
        @sd2d1hour = @sd2d1hour.to_i - 24
      end
      @order_time = (@sd1hour.to_s + "." + @sd1minute.to_s).to_f
      @reverse_time = (@sd2d1hour.to_s + "." + @sd2d1minute.to_s).to_f
    
    # 時間指定した場所が出発地に遠い時
    elsif @destination_1 == @near2
      @sd2d1hour = @skk_h - @hour.to_i
      @sd2d1minute = @skk_m - @minute.to_i

      if @sd2time =~ /\shours|\shour/
        @sd1hour = $`.to_i
        if @sd2time =~ /\shours\s(.+)\smins|\shours\s(.+)\smin|\shour\s(.+)\smins|\shour\s(.+)\smin/
          @sd1minute = $+.to_i
        end
      elsif @sd2time =~ /\smins|\smin/
        @sd1minute = $`.to_i
      end

      if @kk_time =~ /\shours|\shour/
        @sd1d2hour = @sd1hour + $`.to_i
        if @kk_time =~ /\shours\s(.+)\smins|\shours\s(.+)\smin|\shour\s(.+)\smins|\shour\s(.+)\smin/
          @sd1d2minute = @sd1minute + $+.to_i
        end
      elsif @kk_time =~ /\smins|\smin/
        @sd1d2minute = $`.to_i + @sd1minute
      end
      if @sd1d2minute >= 60
        @sd1d2hour = @sd1d2hour.to_i + 1
        @sd1d2minute -= 60
      end
      if @sd1d2hour.to_i >= 24
        @sd1d2hour　= @sd1d2hour - 24
      end
      @order_time = (@sd2d1hour.to_s + "." + @sd2d1minute.to_s).to_f
      @reverse_time = (@sd1d2hour.to_s + "." + @sd1d2minute.to_s).to_f
  
    end
  
   # -------- create.html.erbで使うための変数 -------------
   @orderz = (@order_time - @dif_time).abs
   @reversez = (@reverse_time - @dif_time).abs
  
   # 差分を時刻にする
   @gokei_sd2_h = @sd2hour + @hour.to_i
   @gokei_sd2_m = @sd2minute + @minute.to_i
   if @gokei_sd2_m >= 60
    @gokei_sd2_h += 1
    @gokei_sd2_m -= 60
   end
   if @gokei_sd2_h >= 24
    @gokei_sd2_h　= @gokei_sd2_h.to_i - 24
   end
   @gokei_sd2d1_h = @sd2d1hour + @hour.to_i
   @gokei_sd2d1_m = @sd2d1minute + @minute.to_i
   if @gokei_sd2d1_m >= 60
    @gokei_sd2d1_h += 1
    @gokei_sd2d1_m -= 60
   end
   if @gokei_sd2d1_h >= 24
    @gokei_sd2d1_h = @gokei_sd2d1_h.to_i - 24
   end
   
   @gokei_sd1_h = @sd1hour + @hour.to_i
   @gokei_sd1_m = @sd1minute + @minute.to_i
   if @gokei_sd1_m >= 60
    @gokei_sd1_h += 1
    @gokei_sd1_m -= 60
   end
   if @gokei_sd1_h >= 24
    @gokei_sd1_h　= @gokei_sd1_h.to_i - 24
   end
   @gokei_sd1d2_h = @sd1d2hour + @hour.to_i
   @gokei_sd1d2_m = @sd1d2minute.to_i + @minute.to_i
   if @gokei_sd1d2_m >= 60
    @gokei_sd1d2_h += 1
    @gokei_sd1d2_m -= 60
   end
   if @gokei_sd1d2_h >= 24
    @gokei_sd1d2_h　= @gokei_sd1d2_h - 24
   end


  end
end
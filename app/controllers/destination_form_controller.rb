class DestinationFormController < ApplicationController
  require 'net/https'
  require 'uri'
  require 'json'

  def new
  end

  def create
    @origin = params[:origin]
    destination_1 = params[:destination_1]
    destination_2 = params[:destination_2]
    @hour = params[:hour]
    @minute = params[:minute]
    @keiyu_array = [destination_1, destination_2] # 経由地
    @sk_res = []                                  # 出発地から経由地のjson(s:start, k:keiyu)
    kk_res = []                                   # 経由地間のjson
    sk_keisan =[]                                 # 出発地から経由地の途中計算

    # スタートから経由地の時間を取得する
    [destination_1, destination_2].each do |d|
      uri = URI.encode('https://maps.googleapis.com/maps/api/distancematrix/json?units=imperial&origins='+@origin+'&destinations='+d+'&mode=driving&key='+ENV['API_KEY'])
      json = Net::HTTP.get(URI.parse(uri))
      @sk_res.push(JSON.parse(json))
    end

    # 経由地間の時間を取得する
    uri2 = URI.encode('https://maps.googleapis.com/maps/api/distancematrix/json?units=imperial&origins='+destination_1+'&destinations='+destination_2+'&mode=driving&key='+ENV['API_KEY'])
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


    # s(スタート)からk(経由地1)までの時間演算

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

    # 0-9分以内の場合の分表示の設定(by t:1109)
    if @sk_minute < 10
      @sk_minute = "0" + @sk_minute.to_s
    end


    # k(経由地1)からk(経由地2)までの時間演算
    
    # via→goalの時間の初期設定(by t:1109)
    @kk_h = @sk_hour.to_i
    @kk_m = @sk_minute.to_i

    if @kk_time =~ /\shours|\shour/
      @kk_h = @kk_h + $`.to_i
      if @kk_time =~ /\shours\s(.+)\smins|\shours\s(.+)\smin|\shour\s(.+)\smins|\shour\s(.+)\smin/
        @kk_m = @kk_m + $+.to_i
      end
    elsif @kk_time =~ /\smins|\smin/
      @kk_m = $`.to_i + @kk_m
    end 

    # 分が60を越える時の設定(by t:1109)
    if @kk_m >= 60
      @kk_h += 1
      @kk_m -= 60
    end

    # 時間が24時を回る時の設定(by t:1109)
    if @kk_h >= 24
      @kk_h -= 24
    end

     # 0-9分以内の場合の分表示の設定(by t:1109)
    if @kk_m < 10
      @kk_m = "0" + @kk_m.to_s
    end
    
  end
end
    
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
    @sk_json_array = [] #出発地から経由地のjson(s:start, k:keiyu)
    @kk_json_array = [] #経由地間のjson
    @sk_zikan_array =[] #出発地から経由地の時間

    # スタートから経由地の時間を取得する
    [destination_1, destination_2].each do |d|
      uri = URI.encode('https://maps.googleapis.com/maps/api/distancematrix/json?units=imperial&origins='+@origin+'&destinations='+d+'&mode=driving&key='+ENV['API_KEY'])
      json = Net::HTTP.get(URI.parse(uri))
      @sk_json_array.push(JSON.parse(json))
    end

    # 経由地間の時間を取得する
    uri2 = URI.encode('https://maps.googleapis.com/maps/api/distancematrix/json?units=imperial&origins='+destination_1+'&destinations='+destination_2+'&mode=driving&key='+ENV['API_KEY'])
    json = Net::HTTP.get(URI.parse(uri2))
    @kk_json_array = JSON.parse(json)

    @sk_json_array.each do |d|
      zikan = d['rows'][0]['elements'][0]['duration']['text']
      if zikan =~ /\shours|\shour/
          hour = $`
          if zikan =~ /\shours\s(.+)\smins|\shours\s(.+)\smin|\shour\s(.+)\smins|\shour\s(.+)\smin/
              zikan_new = (hour.to_s + '.' + $+.to_s).to_f
              @sk_zikan_array.push(zikan_new)
          end
      elsif zikan =~ /\smins|\smin/
          zikan_new = ("0." + $`.to_s).to_f
          @sk_zikan_array.push(zikan_new)
      end
  
    end
   
  
    if @sk_zikan_array[0] < @sk_zikan_array[1]
      big = 1
      small = 0
    else
      big = 0
      small = 1
    end

    @near1 = @keiyu_array[small]
    @near2 = @keiyu_array[big]


    # スタートから近い経由地までの時間
    @sk_zikan = @sk_json_array[small]['rows'][0]['elements'][0]['duration']['text']
    # 近い経由地から経由地までの時間
    @kk_zikan = @kk_json_array['rows'][0]['elements'][0]['duration']['text']


    ###### s(スタート)からk(経由地1)までの時間演算
    if @sk_zikan =~ /\shours|\shour/
      @sk_h = $`.to_i + @hour.to_i
      if @sk_zikan =~ /\shours\s(.+)\smins|\shours\s(.+)\smin|\shour\s(.+)\smins|\shour\s(.+)\smin/
        @sk_m = $+.to_i + @minute.to_i
        if @sk_m > 60
          @sk_h += 1
          @sk_m -= 60
        end
      end
    elsif @sk_zikan =~ /\smins|\smin/
      @sk_m = $`.to_i + @minute.to_i
      if @sk_m > 60
        @sk_h += 1
        @sk_m -= 60
      else
        @sk_h = @hour
      end
    end

    ###### k(経由地1)からk(経由地2)までの時間演算
    if @kk_zikan =~ /\shours|\shour/
      @kk_h = @sk_h.to_i + @hour.to_i
      if @kk_zikan =~ /\shours\s(.+)\smins|\shours\s(.+)\smin|\shour\s(.+)\smins|\shour\s(.+)\smin/
        @kk_m = @sk_m.to_i + @minute.to_i
        if @kk_m > 60
          @kk_h += 1
          @kk_m -= 60
        end
      end
    elsif @kk_zikan =~ /\smins|\smin/
      @kk_m = $`.to_i + @sk_m.to_i
      if @kk_m > 60
        @kk_h += 1
        @kk_m -= 60
      else
        @kk_h = @sk_h
      end
    end


    
  end

end


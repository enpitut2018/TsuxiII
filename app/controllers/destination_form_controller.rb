class DestinationFormController < ApplicationController
  require 'net/https'
  require 'uri'
  require 'json'

  def new
  end

  def create
    @q_ori = params[:q_ori]
    @q1 = params[:q1]
    @q2 = params[:q2]
    @array = [@q1, @q2]
    @array_2 = []
    @array.each do |d|
      @uri = URI.encode('https://maps.googleapis.com/maps/api/distancematrix/json?units=imperial&origins='+@q_ori+'&destinations='+d+'&mode=driving&key='+ENV['API_KEY'])
      uri = URI.parse(@uri)
      json = Net::HTTP.get(uri)
      @result = JSON.parse(json)
      @array_2.push(@result)
    end
    
    # 例) 13 hours 30 mins　を 13.3 の形にして配列のぶち込む
    # ただし　1 hour とか 1 min もあるから場合分け
    @zikan_array = Array.new()

    @array_2.each do |d|
      zikan = d['rows'][0]['elements'][0]['duration']['text'] # '1hour20min'が入る
      if zikan =~ /\shours|\shour/
          @hour = $`     # "1 hour 20mins"のhourより前の数字が抜き出される
          if zikan =~ /\shours\s(.+)\smins|\shours\s(.+)\smin|\shour\s(.+)\smins|\shour\s(.+)\smin/
              @min = $+.to_f
              @min_to_hour = @min / 60
              @zikan_new = @hour + @min_to_hour
              # @zikan_new = (@hour.to_s + '.' + @min.to_s).to_f
              @zikan_array.push(@zikan_new)
          end
      elsif zikan =~ /\smins|\smin/
          @min = $`
          @zikan_new = ("0." + @min.to_s).to_f
          @zikan_array.push(@zikan_new)
      end
  
    end
   
  
    # 2つの配列を1つのハッシュ{ 行き先 => かかる時間 }にする
    # value(かかる時間)でソート
    hash = Hash[@array.zip @zikan_array]
    @hash_new = Hash[hash.sort_by{ |_, v| v }]
    @bigvalue = 0
    @smallvalue = 1
    if @zikan_array[0] < @zikan_array[1]
      @bigvalue = 1
      @smallvalue = 0
    end
   @near =  @array[@smallvalue]
   @distant = @array[@bigvalue]

  end

end



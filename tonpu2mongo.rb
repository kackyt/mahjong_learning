#!/usr/bin/env ruby
# -*- encoding: utf-8 -*-

require 'bundler/setup'
require 'json'
require 'date'
require 'mongo'

Bundler.require

class TonpuKyoku
  attr_reader :kyoku, :honba, :riichibou, :doras, :uradoras, :haipais, :actions, :result, :kazes
  def initialize
    @kazes = []
    @haipais = []
    @actions = []
  end
  
  def to_hash
    {
      kyoku: @kyoku,
      honba: @honba,
      riichibou: @riichibou,
      doras: @doras,
      uradoras: @uradoras,
      haipais: @haipais,
      actions: @actions,
      result: @result,
      kazes: @kazes
    }
  end
  
  def hais(str)
    chs = str.chars
    hais = []

    while c = chs.shift
      case c
      when '東'
        hais.push({ no:27, aka: false })
      when '南'
        hais.push({ no:28, aka: false })
      when '西'
        hais.push({ no:29, aka: false })
      when '北'
        hais.push({ no:30, aka: false })
      when '白'
        hais.push({ no:31, aka: false })
      when '発'
        hais.push({ no:32, aka: false })
      when '中'
        hais.push({ no:33, aka: false })
      else
        num = c.to_i - 1
        aka = false
        c = chs.shift
        
        case c
        when 'p'
          num += 9
        when 's'
          num += 18
        when 'M'
          num += 64
        when 'P'
          num += 9
          aka = true
        when 'S'
          num += 18
          aka = true
        end
        
        hais.push({ no: num, aka: aka })
      end
    end
    
    hais
  end
  

  def parse(instream)
    line = instream.gets.chomp
    m = /(東|南)([1-4])局 ([0-9]+)本場\(リーチ([0-9]+)\) (.+)$/.match(line)
    if m
      captures = m.captures
      @kyoku = captures.shift == '南' ? 4 : 0
      @kyoku += captures.shift.to_i
      @honba = captures.shift.to_i
      @riichibou = captures.shift.to_i
      @result = {
        scores: []
      }
      
      scs = captures.shift.split(/ /)
      
      while name = scs.shift
        score = scs.shift.to_i
        @result[:scores].push({ name: name, score: score })
      end
      
      
    else
      return false
    end
    
    line = instream.gets
    m = /([^ ]+)/.match(line)
    if m
      @result[:yaku] = m.captures[0]
    end
    
    0.upto(3) do |idx|
      line = instream.gets.chomp
      m = /\[[1-4](東|南|西|北)\]([^ ]+)/.match(line)
      if m
        case m.captures[0]
        when '東'
          @kazes.push(0)
        when '南'
          @kazes.push(1)
        when '西'
          @kazes.push(2)
        when '北'
          @kazes.push(3)
        end
        
        @haipais.push(hais(m.captures[1]))
      end
    end
    
    m = /\[表ドラ\]()\]([^ ]+)\[裏ドラ\]()\]([^ ]+)/.match(line)
    if m
      @doras = hais(m.captures[0])
      @uradoras = hais(m.captures[1])
    end
    
    until (line = instream.gets.chomp).empty?
      m = /\* (.+)$/.match(line)
      prev = nil
      next unless m
      m.captures[0].split(/ /).each do |str|
        action = {}
        chs = str.chars
        action[:self] = chs[0].to_i
        
        case chs[1]
        when 'G'
          action[:type] = 'tsumo'
          action[:hais] = hais(str[2 .. -1])
        when 'd'
          action[:type] = 'dahai'
          action[:hais] = hais(str[2 .. -1])
          action[:tsumogiri] = false
        when 'D'
          action[:type] = 'dahai'
          action[:hais] = hais(str[2 .. -1])
          action[:tsumogiri] = true
        when 'R'
          action[:type] = 'riichi'
        when 'K'
          action[:type] = 'kan'
          action[:hais] = hais(str[2 .. -1])
        when 'N'
          action[:type] = 'pon'
          action[:hais] = hais(str[2 .. -1])
        when 'C'
          action[:type] = 'tii'
          action[:hais] = hais(str[2 .. -1])
        when 'A'
          if @actions.last[:type] == 'dahai'
            action[:type] = 'ron'
          else
            action[:type] = 'tsumo'
          end
          action[:hais] = @actions.last[:hais]
        end

        @actions.push(action)
      end
    end
    
    true
  end
end



class TonpuHaifu
  attr_reader :players, :initial_score, :kyokus, :date, :is_valid
  def initialize
    @players = []
    @kyokus = []
    @is_valid = false
  end
  
  def to_hash
    {
      players: @players,
      initial_score: @initial_score,
      kyokus: @kyokus.map { |item| item.to_hash },
      date: @date
    }
  end
  
  def parse(instream)
    begin
      until m = instream.gets.match(/==== .+ ([0-9]{4}\/[0-9]{2}\/[0-9]{2} [0-9]{2}:[0-9]{2}) ====/)
        return false if instream.eof?
      end
    
      if m
        @_date = DateTime.strptime(m.captures[0], '%Y/%m/%d %H:%M')
        @date = {
          year: @_date.year,
          month: @_date.month,
          day: @_date.day,
          hour: @_date.hour,
          min: @_date.min,
          sec: @_date.sec
        }
      end
      
      m = instream.gets.chomp.match(/持点([0-9]+) (.+)/)
      
      if m
        @initial_score = m.captures[0].to_i
        pls = m.captures[1].split(/ /)
        
        while name = pls.shift
          
          rating = pls.shift[1..-1].to_i
        
          @players.push({ name: name[3..-1] , rating: rating })
        end
      end
      
      while (kyoku = TonpuKyoku.new).parse(instream)
        @kyokus.push(kyoku)
      end

    rescue => e
      return true
    end
    @is_valid = true
    true
  end
end


client = Mongo::Client.new(['localhost:27017'], :database => 'tonpuhaifu')

coll = client[:haifu]

Dir.glob('*.txt') do |filepath|
  File.open(filepath, 'r:shift_jis:utf-8') do |file|
    while (haifu = TonpuHaifu.new).parse(file)
      coll.insert_one(haifu.to_hash) if haifu.is_valid
    end
  end
end


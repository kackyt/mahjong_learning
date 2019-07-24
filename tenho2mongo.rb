require 'bundler/setup'
require 'zlib'
require 'nokogiri'
require 'mongo'
require './mahjong_lib'

Bundler.require

class TenhouDocument < Nokogiri::XML::SAX::Document
  attr_reader :current_haifu

  def initialize
    @has_aka = false
    @is_valid = true
  end

  # 天鳳の牌番号をhash形式に変換する
  def num_to_hai(num)
    hai_num = (num / 4).to_i
    hai_id = num % 4
    is_aka = @has_aka && hai_id == 0 && hai_num < 27 && (hai_num % 9) == 4
    { no: hai_num, aka: is_aka }
  end

  def start_element(name, attr_array=nil)
    attr = {}
    attr_array.each do |item|
      attr[item[0]] = item[1]
    end
    puts "name = #{name} attr = #{attr}"
    return if @is_valid == false && name != 'UN' # 局データが無効
    case name
    when 'GO'
      # 赤牌の判定
      tp = attr['type'].to_i
      if (tp & 0x02) != 0
        @has_aka = true
      else
        @has_aka = false
      end
    when 'UN'
      # プレーヤー情報
      unless attr['rate'] && attr['n0'] && attr['n1'] && attr['n2'] && attr['n3']
        # 無効なデータ
        @is_valid = false
      else
        rate = attr['rate'].split(',').map{ |x| x.to_f }
        @current_haifu = Haifu.new([
        {name: attr['n0'], rate: rate[0] },
        {name: attr['n1'], rate: rate[1] },
        {name: attr['n2'], rate: rate[2] },
        {name: attr['n3'], rate: rate[3] }])
        @is_valid = true
      end
    when 'TAIKYOKU'
      # do nothing
    when 'INIT'
      # 局の開始
      kyoku_num, honba, riichi_bou, _, _, dora = attr['seed'].split(',').map { |x| x.to_i }
      kaze_table = [[0, 1, 2, 3], [3, 0, 1, 2], [2, 3, 0, 1], [1, 2, 3, 0]]
      haipais = []
      [attr['hai0'], attr['hai1'], attr['hai2'], attr['hai3']].each do |haipai|
        haipais << haipai.split(',').map { |item| num_to_hai(item.to_i) }.sort_by { |item| item[:no] }
      end
      if @current_kyoku
        @current_kyoku.simulate_action
        @current_haifu.add_kyoku(@current_kyoku)
      end
      @current_kyoku = Kyoku.new(kyoku_num, honba, riichi_bou,
        [num_to_hai(dora)], kaze_table[attr['oya'].to_i], haipais)
    when 'DORA'
      @current_kyoku.add_dora(num_to_hai(attr['hai'].to_i))
    when 'N'
      # なき
      who = attr['who'].to_i + 1
      # メンツコード(複雑)
      m = attr['m'].to_i

      if (m & 0x0004) != 0
        # チー
        p = m >> 10
        r = p % 3
        p = (p / 3).to_i
        color = p / 7
        n = p % 7
        pai_ids = [m & 0x0018, m & 0x0060, m & 0x0180]

        pais = []
        for i in 0..2 do
          if i != r
            is_aka = @has_aka && pai_ids[i] == 0 && n + i == 4
            pais << { no: color * 9 + n + i, aka: is_aka }
          end
        end

        @current_kyoku.add_action({
          type: 'tii',
          self: who,
          hais: pais
        })
      elsif (m & 0x0008) != 0
        # ポン
        @current_kyoku.add_action({
          type: 'pon',
          self: who
        })
      elsif (m & 0x0010) != 0
        # 加えカン
        @current_kyoku.add_action({
          type: 'kan',
          self: who
        })
      else
        # 暗カンまたは大明槓
        @current_kyoku.add_action({
          type: 'kan',
          self: who
        })
      end
    when 'REACH'
      if attr['step'] == '1'
        @current_kyoku.add_action({
          type: 'riichi',
          self: attr['who'].to_i + 1
        })
      end
    when 'AGARI'
      who = attr['who'].to_i + 1
      fromWho = attr['fromWho'].to_i + 1
      if attr['doraHaiUra']
        uradoras = attr['doraHaiUra'].split(',').map { |x| num_to_hai(x.to_i) }
        @current_kyoku.set_uradora(uradoras)
      end

      fu, _, mangan = attr['ten'].split(',').map { |x| x.to_i }
      han = 0
      sc = attr['sc'].split(',').map { |x| x.to_i }

      yaku_table = [
        '門前清自摸和', '立直', '一発', '槍槓', '嶺上開花',
        '海底摸月', '河底撈魚', '平和', '断幺九', '一盃口',
        '自風 東', '自風 南', '自風 西', '自風 北', '場風 東',
        '場風 南', '場風 西', '場風 北', '役牌 白', '役牌 發',
        '役牌 中', '両立直', '七対子', '混全帯幺九', '一気通貫',
        '三色同順', '三色同刻', '三槓子', '対々和', '三暗刻',
        '小三元', '混老頭', '二盃口', '純全帯幺九', '混一色',
        '清一色', '', '天和', '地和', '大三元',
        '四暗刻', '四暗刻単騎', '字一色', '緑一色', '清老頭',
        '九蓮宝燈', '純正九蓮宝燈', '国士無双', '国士無双１３面', '大四喜',
        '小四喜', '四槓子', 'ドラ', '裏ドラ', '赤ドラ',
      ]

      yaku = []
      
      if attr['yaku']
        yakus = attr['yaku'].split(',').map { |x| x.to_i }
        # 役の走査
        (0..yakus.length-1).step(2) do |idx|
          yaku << yaku_table[yakus[idx]]
          han += yakus[idx+1]
        end
      elsif attr['yakuman']
        yakus = attr['yakuman'].split(',').map { |x| x.to_i }
        yakus.each do |num|
          yaku << yaku_table[num]
          han += 13
        end
      end

      @current_kyoku.add_result({
        han: han,
        fu: fu,
        mangan: mangan,
        yaku: yaku,
        scores: [sc[1] * 100, sc[3] * 100, sc[5] * 100, sc[7] * 100]
      })

      if who == fromWho
        # ツモあがり
        @current_kyoku.add_action({
          type: 'tsumo',
          self: who
        })
      else
        # ロンあがり
        @current_kyoku.add_action({
          type: 'ron',
          self: who
        })
      end
    when 'RYUUKYOKU'
      type_table = {
        'nm' => '流し満貫',
        'yao9' => '九種九牌',
        'kaze4' => '四風連打',
        'reach4' => '四家立直',
        'ron3' => '三家和了',
        'kan4' => '四槓散了'
      }
      name = type_table[attr['type']]
      unless name
        name = '荒牌'
      end
      sc = attr['sc'].split(',').map { |x| x.to_i }
      @current_kyoku.add_result({
        han: 0,
        fu: 0,
        mangan: 0,
        yaku: name,
        scores: [sc[1] * 100, sc[3] * 100, sc[5] * 100, sc[7] * 100]
      })
    else
      if num = ['T', 'U', 'V', 'W'].index { |x| name.start_with?(x) }
        # ツモギリ判定のためにツモ牌Noを記憶
        @tsumohai = name[1..-1].to_i
        @current_kyoku.add_action({
          type: 'tsumohai',
          self: num + 1,
          hais: [num_to_hai(@tsumohai)]
        })
      elsif num = ['D', 'E', 'F', 'G'].index { |x| name.start_with?(x) }
        sutehai = name[1..-1].to_i
        @current_kyoku.add_action({
          type: 'dahai',
          self: num + 1,
          hais: [num_to_hai(sutehai)],
          tsumogiri: @tsumohai == sutehai
        })
      end
    end
  end
  
  def end_element(name, attr=nil)
  end
end



dir = ARGV[0]
database_name = ARGV[1]

client = Mongo::Client.new(['localhost:27017'], :database => database_name)
coll = client[:haifu]

tenhou_doc = TenhouDocument.new
parser = Nokogiri::XML::SAX::Parser.new(tenhou_doc)

Dir.glob("#{dir}/**/*").each do |file|
  if FileTest.file?(file)
    puts "open #{file}"
    Zlib::GzipReader.open(file) do |input|
      xml_str = input.read # いったん全部解凍する
      parser.parse(xml_str)
      coll.insert_one(tenhou_doc.current_haifu.to_hash)
    end
  end
end

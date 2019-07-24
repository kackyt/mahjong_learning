class Player
  attr_reader :pais, :naki_mentsu, :kawa

  def initialize(haipai)
    @pais = haipai
    @naki_mentsu = []
    @kawa = []
  end

  def to_hash
    {
      hais: @pais,
      naki: @naki_mentsu,
      kawa: @kawa
    }
  end

  def tsumohai(pai)
    @pais << pai
    @pais.sort_by! {|p| p[:no] }
  end

  def dahai(pai, tsumogiri, riichi)
    pai[:riichi] = riichi
    pai[:tsumogiri] = tsumogiri
    @pais.delete_at(@pais.find_index{|item| item[:no] == pai[:no] && item[:aka] == pai[:aka]})
    @kawa << pai
  end

  def tii(pais, naki_pai)
    pais.each do |item|
      @pais.delete_at(@pais.find_index {|p| p[:no] == item[:no] && p[:aka] == item[:aka] })
    end
    pais << naki_pai
    @naki_mentsu << { type: 'shuntsu', hais: pais }
  end

  def pon(naki_pai)
    pais = []
    2.times {
      idx = @pais.find_index { |x| x[:no] == naki_pai[:no] }
      pais << @pais[idx]
      @pais.delete_at(idx)
    }

    pais << naki_pai
    @naki_mentsu << { type: 'koutsu', hais: pais }
  end

  def tsumo
  end

  def ron(pai)
    @pais << pai
  end

  def minkan(pai)
    pais = @pais.find_all { |x| x[:no] == pai[:no] }
    @pais.reject! { |x| x[:no] == pai[:no] }
    pais_a = pais.to_a
    pais_a << pai
    @naki_mentsu << { type: 'minkan', hais: pais_a  }
  end

  def ankan(pai)
    pais = @pais.find_all { |x| x[:no] == pai[:no] }
    @pais.reject! { |x| x[:no] == pai[:no] }
    @naki_mentsu << { type: 'ankan', hais: pais.to_a }
  end
end

class Kyoku
  attr_reader :kyoku, :honba, :riichibou, :doras, :uradoras, :haipais, :actions, :result, :kazes
  def initialize(kyoku_num, honba, riichibou, doras, kazes, haipais)
    @kyoku = kyoku_num
    @honba = honba
    @riichibou = riichibou
    @doras = doras
    @kazes = kazes
    @haipais = haipais
    @actions = []
    @states = []
    @players = []
    @results = []
    @uradoras = []
  end

  def to_hash
    {
      kyoku: @kyoku,
      honba: @honba,
      riichibou: @riichibou,
      doras: @doras,
      uradoras: @uradoras,
      states: @states,
      results: @results,
      kazes: @kazes
    }
  end

  def add_result(result)
    @results << result
  end

  def add_dora(dora)
    @doras << dora
  end

  def add_uradora(dora)
    @uradoras << dora
  end

  def set_dora(doras)
    @doras = doras
  end

  def set_uradora(doras)
    @uradoras = doras
  end

  def add_action(action)
    @actions << action
  end

  # actionをなめて、手牌をシミュレートする
  def simulate_action
    prev_action = nil
    riichi = false
    4.times { |i|
      @players << Player.new(@haipais[i])
    }
    for action in @actions
      case action[:type]
      when 'tsumohai'
        @players[action[:self]-1].tsumohai(action[:hais][0])
      when 'dahai'
        @players[action[:self]-1].dahai(action[:hais][0], action[:tsumogiri], riichi)
        riichi = false
      when 'riichi'
        riichi = true
      when 'tii'
        aite = prev_action[:self]-1
        naki_hai = @players[aite].kawa.pop
        @players[action[:self]-1].tii(action[:hais], naki_hai)
      when 'pon'
        aite = prev_action[:self]-1
        naki_hai = @players[aite].kawa.pop
        @players[action[:self]-1].pon(naki_hai)
      when 'kan'
        if prev_action[:type] == 'dahai'
        else
        end
      when 'ron'
        aite = prev_action[:self]-1
        naki_hai = @players[aite].kawa.pop
        @players[action[:self]-1].ron(naki_hai)
      when 'tsumo'
        # do nothing
      end

      unless riichi
        # stateを保存
        tmp = Marshal.dump(@players)
        players = Marshal.load(tmp)

        @states << { players: players.map { |x| x.to_hash }, action: action }
        riichi = false
      end
      prev_action = action
    end
  end

end

class Haifu
  attr_reader :players, :initial_score, :kyokus, :date, :is_valid
  def initialize(players)
    @players = players
    @kyokus = []
    @is_valid = true
  end

  def add_kyoku(kyoku)
    @kyokus << kyoku
  end

  def to_hash
    {
      players: @players,
      initial_score: @initial_score,
      kyokus: @kyokus.map { |item| item.to_hash },
      date: @date
    }
  end
end


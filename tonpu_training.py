import numpy as np
from pymongo import MongoClient
from mahjong_lib import search_agari
import csv

client = MongoClient('localhost', 27017)

db = client.tonpuhaifu

tehai_training = open('training_tehai.csv', 'w')
yomi_training = open('training_yomi.csv', 'w')
yomi_rnn_training = open('training_yomi_rnn.csv', 'w')
train_tehai_writer = csv.writer(tehai_training, lineterminator='\n')
train_yomi_writer = csv.writer(yomi_training, lineterminator='\n')
train_yomi_rnn_writer = csv.writer(yomi_rnn_training, lineterminator='\n')

tehai_test = open('test_tehai.csv', 'w')
yomi_test = open('test_yomi.csv', 'w')
yomi_rnn_test = open('test_yomi_rnn.csv', 'w')
test_tehai_writer = csv.writer(tehai_test, lineterminator='\n')
test_yomi_writer = csv.writer(yomi_test, lineterminator='\n')
test_yomi_rnn_writer = csv.writer(yomi_rnn_test, lineterminator='\n')

# プレーヤーの牌情報を配列で持ってくるpipeline
pipeline = [
  {
    "$project": {
      "_id" :0,
      "result": {
        "$reduce": {
          "input": "$kyokus.states",
          "initialValue": [],
          "in": {
            "$concatArrays": ["$$value", "$$this"]
          }
        }
      }
    }
  }
]

collection = db.haifu

results = collection.aggregate(pipeline = pipeline)
kyoku_num = collection.estimated_document_count()
# ランダムな局をテスト用として使う
test_idx = np.random.randint(0, kyoku_num)
kidx = 0
print(test_idx)

for result in results:
  if np.random.random() <= 0.01:
    output_yomi = test_yomi_writer
    output_yomi_rnn = test_yomi_rnn_writer
    output_tehai = test_tehai_writer
  else:
    output_yomi = train_yomi_writer
    output_yomi_rnn = train_yomi_rnn_writer
    output_tehai = train_tehai_writer
  states = result['result']
  states_num = len(states)
  kidx += 1
  print("process (", kidx, "/", kyoku_num, ")")

  for state in states:
    players = state['players']
    action = state['action']
    player_num = len(players)
    if action['type'] == 'dahai':
      yomi_idx = action['self'] -1
    else:
      yomi_idx = -1

    for pidx in range(player_num):
      player = players[pidx]
      hais = np.zeros(34, dtype=np.int32)
      kawa = np.zeros(35, dtype=np.int32)
      if yomi_idx != pidx:
          continue
      try:
        for hai in player['hais']:
          hais[hai['no']] += 1

        for naki in player['naki']:
          for hai in naki['hais']:
            hais[hai['no']] += 1

        for kw in player['kawa']:
          kawa[kw['no']] += 1
          if kw['tsumogiri']:
            kawa[34] += 1

        agari = search_agari(hais)
        l = [ agari[3] ]
        l.extend(kawa.tolist())
        output_yomi.writerow(l)
        l = [ agari[3] ]
        l.extend(hais.tolist())
        output_tehai.writerow(l)
        haivec = np.zeros(35, dtype=np.int32)
        haivec[action['hais'][0]['no']] += 1
        if action['tsumogiri']:
            haivec[34] = 1
        l = [kidx, pidx, agari[3]]
        l.extend(haivec.tolist())
        output_yomi_rnn.writerow(l)
      except TypeError:
        pass
      else:
        pass

tehai_training.close()
yomi_training.close()
tehai_test.close()
yomi_test.close()

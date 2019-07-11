# -*- encoding: utf-8 -*-
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
          "input": "$kyokus",
          "initialValue": [],
          "in": {
            "$concatArrays": ["$$value", ["$$this.states"]]
          }
        }
      }
    }
  }
]

collection = db.haifu

results = collection.aggregate(pipeline = pipeline)
doc_num = collection.estimated_document_count()
didx = 0
kidx = 0

for result in results:
  if np.random.random() <= 0.01:
    output_yomi = test_yomi_writer
    output_yomi_rnn = test_yomi_rnn_writer
    output_tehai = test_tehai_writer
  else:
    output_yomi = train_yomi_writer
    output_yomi_rnn = train_yomi_rnn_writer
    output_tehai = train_tehai_writer
  kyokus = result['result']
  kyoku_num = len(kyokus)
  didx += 1
  print("process (", didx, "/", doc_num, ")")

  for kyoku in kyokus:
    state_num = [0, 0, 0, 0]
    state_pos = [0, 0, 0, 0]
    for state in kyoku:
      action = state['action']
      if action['type'] == 'dahai':
        state_num[action['self']-1] += 1
    for state in kyoku:
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
          if state_num[yomi_idx] >= 10 and state_pos[yomi_idx] <= 10:
            haivec = np.zeros(35, dtype=np.int32)
            haivec[action['hais'][0]['no']] += 1
            if action['tsumogiri']:
              haivec[34] = 1
            l = [kidx*4+pidx, agari[3]]
            l.extend(haivec.tolist())
            output_yomi_rnn.writerow(l)
            state_pos[yomi_idx] += 1
        except TypeError:
          pass
        else:
          pass
    kidx += 1

tehai_training.close()
yomi_training.close()
yomi_rnn_training.close()
tehai_test.close()
yomi_test.close()
yomi_rnn_test.close()

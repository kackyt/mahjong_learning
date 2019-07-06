# 一人麻雀シミュレータークラス MahjongState
import numpy as np

def search_toitsu(tehai):
    for i in range(34):
        if tehai[i] >= 2:
            tehai[i] -= 2
            return 1
    return 0

def search_koutsu_r(tehai):
    for i in reversed(range(34)):
        if tehai[i] >= 3:
            tehai[i] -= 3
            return 1
    return 0

def search_shuntsu_r(tehai):
    for i in reversed([0, 1, 2, 3, 4, 5, 6, 9, 10, 11, 12, 13, 14, 15, 18, 19, 20, 21, 22, 23, 24]):
        if tehai[i] >= 1 and tehai[i+1] >= 1 and tehai[i+2]:
            tehai[i] -= 1
            tehai[i+1] -= 1
            tehai[i+2] -= 1
            return 1
    return 0

def search_koutsu(tehai):
    for i in range(34):
        if tehai[i] >= 3:
            tehai[i] -= 3
            return 1
    return 0

def search_shuntsu(tehai):
    for i in [0, 1, 2, 3, 4, 5, 6, 9, 10, 11, 12, 13, 14, 15, 18, 19, 20, 21, 22, 23, 24]:
        if tehai[i] >= 1 and tehai[i+1] >= 1 and tehai[i+2]:
            tehai[i] -= 1
            tehai[i+1] -= 1
            tehai[i+2] -= 1
            return 1
    return 0

def search_tahtsu(tehai):
    indices = np.nonzero(tehai)[0]
    num = 0
    i = 0
    while i < indices.size:
        idx = indices[i]
        i+=1
        if idx >= 27:
            break
        if idx % 9 == 8:
            continue
        if idx % 9 < 7 and tehai[idx+2] >= 1:
            i += 1
            num += 1
        elif tehai[idx+1] >= 1:
            i += 1
            num += 1
    return num

# score:
#  0 -> あがっている
# 1 -> テンパイ
# 2 -> 一向聴
# 3 -> 二向聴
def get_agari_score(tehai, mentsu):
    count = np.sum(tehai)
    mentsu_count = mentsu[1] + mentsu[2]
    
    if mentsu[0] == 0:
        if mentsu_count == 4:
            return 1
        elif mentsu_count == 3:
            numtah = search_tahtsu(tehai)
            if numtah >= 1:
                return 2
            else:
                return 3
        elif mentsu_count == 2:
            numtah = search_tahtsu(tehai)
            if numtah >= 2:
                return 3
            elif numtah == 1:
                return 4
            else:
                return 5
        elif mentsu_count == 1:
            numtah = search_tahtsu(tehai)
            if numtah >= 3:
                return 4
            elif numtah == 2:
                return 5
            elif numtah == 1:
                return 6
            else:
                return 7
        else:
            numtah = search_tahtsu(tehai)
            if numtah >= 4:
                return 5
            elif numtah == 3:
                return 6
            else:
                return 7
    else:
        if mentsu_count == 4:
            return 0
        elif mentsu_count == 3:
            numtah = search_tahtsu(tehai) + (mentsu[0] - 1)
            if numtah >= 1:
                return 1
            else:
                return 2
        elif mentsu_count == 2:
            numtah = search_tahtsu(tehai) + (mentsu[0] - 1)
            if numtah >= 2:
                return 2
            elif numtah == 1:
                return 3
            else:
                return min([4, 7 - mentsu[0]])
        elif mentsu_count == 1:
            numtah = search_tahtsu(tehai) + (mentsu[0] - 1)
            if numtah >= 3:
                return min([3, 7 - mentsu[0]])
            elif numtah == 2:
                return min([4, 7 - mentsu[0]])
            elif numtah == 1:
                return min([5, 7- mentsu[0]])
            else:
                return min([6, 7 - mentsu[0]])
        else:
            numtah = search_tahtsu(tehai) + (mentsu[0] - 1)
            if numtah >= 4:
                return min([4, 7 - mentsu[0]])
            elif numtah == 3:
                return min([5, 7 - mentsu[0]])
            elif numtah == 2:
                return min([6, 7- mentsu[0]])
            else:
                return min([7, 7- mentsu[0]])

def search_agari(tehai):            
    stack = []
    stack.append((np.copy(tehai), 0, 0, 0))
    result = []
        
    while len(stack) > 0:
        status = stack.pop(-1)
        found = False
        cp = np.copy(status[0])
        if search_koutsu(cp) == 1:
            stack.append((cp, status[1], status[2] + 1, status[3]))
            found = True
            cp = np.copy(status[0])
            
        if search_shuntsu(cp) == 1:
            stack.append((cp, status[1], status[2], status[3] + 1))
            found = True
            cp = np.copy(status[0])

        if search_koutsu_r(cp) == 1:
            stack.append((cp, status[1], status[2] + 1, status[3]))
            found = True
            cp = np.copy(status[0])
            
        if search_shuntsu_r(cp) == 1:
            stack.append((cp, status[1], status[2], status[3] + 1))
            found = True
            cp = np.copy(status[0])
            
        if found == False:
            toitsu = 0
            while search_toitsu(cp) == 1:
                toitsu += 1
                
            mentsu = (toitsu, status[2], status[3])
            result.append((toitsu, status[2], status[3], get_agari_score(cp, mentsu)))
        
    return min(result, key=lambda x: x[3])

class MahjongState:
    def __init__(self, ikasama_num=-1):
        self.ikasama_num = ikasama_num
        
    def kyoku_start(self):
        self.yama = np.array([int(i/4) for i in range(136)])
        np.random.shuffle(self.yama)
        self.tehai = np.zeros(34)
        
        # 山から14枚取り出す
        hais = self.yama[0:14]
        
        self.yama_pointer = 14
        
        # 牌を番号リストに並べる
        for hai in hais:
            self.tehai[hai] += 1.0

    def ikasama_start(self, num):
        self.tehai = np.zeros(34)
        remain = np.ones(34, dtype=np.int32) * 4
        mem = np.zeros(34, dtype=np.int32)
        fill_ok = False
        
        # アタマを作る
        while fill_ok == False:
            v = np.random.randint(34)
            if remain[v] >= 2:
                remain[v] -= 2
                mem[v] += 2
            fill_ok = True
        
        # 面子を作る
        for i in range(4):
            fill_ok = False
            shuntsu = 21 * 16 # 順子の出やすさ補正
            while fill_ok == False:
                v = np.random.randint(shuntsu+34)
                if v < shuntsu:
                    v = v % 21
                    st = int(int(v / 7) * 9 + v % 7)
                    print("shuntsu = ", st)
                    if remain[st] >= 1 and remain[st+1] >= 1 and remain[st+2] >= 1:
                        remain[st] -= 1
                        remain[st+1] -= 1
                        remain[st+2] -= 1
                        mem[st] += 1
                        mem[st+1] += 1
                        mem[st+2] += 1
                        fill_ok = True
                else:
                    print("koutsu = ", v-shuntsu)
                    if remain[v-shuntsu] >= 3:
                        remain[v-shuntsu] -= 3
                        mem[v-shuntsu] += 3
                        fill_ok = True
        
        print("before = ", mem)

        # 適当に上がり形を崩す
        for i in range(num):
            mem_idxs = np.nonzero(mem)
            remain_idxs = np.nonzero(remain)
            
            v = np.random.randint(len(mem_idxs[0]))
            v2 = np.random.randint(len(remain_idxs[0]))
            
            # 入れ替える
            mem[mem_idxs[0][v]] -= 1
            remain[mem_idxs[0][v]] += 1
            
            remain[remain_idxs[0][v2]] -= 1
            mem[remain_idxs[0][v2]] += 1
            
        print("after = ", mem)
        # 手牌
        self.tehai = mem.astype(np.float32)
        
        # 山
        yama = []
        for i in range(34):
            yama.extend([i for ii in range(remain[i])])
        
        self.yama = np.array(yama)
        np.random.shuffle(self.yama)
        self.yama_pointer = 0
        

    def calc_mentsu(self):
        return search_agari(self.tehai)

    # 強化学習用EnvironmentのAPI
    def get_state(self):
        return self.tehai
#        return np.append(self.tehai, self.visible_hais)
    
    def step(self, action):
        reward = 0
        if self.tehai[action] >= 1:
            # 捨牌
            self.tehai[action] -= 1
            # ツモ牌
            hai = self.yama[self.yama_pointer]
            self.yama_pointer += 1
            self.tehai[hai] += 1
            self.visible_hais[hai] += 1
            mentsu = self.calc_mentsu()
            self.steps += 1
            # あがっていたら報酬をもらえる
            if mentsu[3] == 0:
                reward = 1.0
            elif self.steps == 18:
                reward = 0 #1.0 / (mentsu[3] + 1.0)
        return self.get_state(), reward, reward >= 1.0 or self.steps >= 18            
        
    def get_num_actions(self):
        return 34
    
    def reset(self):
        if self.ikasama_num >= 0:
            self.ikasama_start(self.ikasama_num)
        else:
            self.kyoku_start()
        self.visible_hais = self.tehai.copy()
        self.steps = 0
        return self.get_state()

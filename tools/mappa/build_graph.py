import json,cv2,math
nodes=json.load(open('det_nodes.json')); segs=json.load(open('segs.json'))
edges=[tuple(s['nodes']) for s in segs if len(s['nodes'])==2 and not s['ends']]
new=[]
def near(p):
    for n in new:
        if math.hypot(n['x']-p[0],n['y']-p[1])<70: return n
for s in segs:
    if len(s['nodes'])==1 and s['ends']:
        # choose farthest end from the node
        nd=nodes[s['nodes'][0]]
        e=max(s['ends'],key=lambda p:math.hypot(p[0]-nd['x'],p[1]-nd['y']))
        n=near(e)
        if not n:
            n={'id':1000+len(new),'kind':'end','x':e[0],'y':e[1],'color':None}
            new.append(n)
        edges.append((s['nodes'][0],n['id']))
allnodes=nodes+new
json.dump({'nodes':allnodes,'edges':edges},open('graph_auto.json','w'))
print(len(allnodes),len(edges))
